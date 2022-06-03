package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"mime"
	"mime/multipart"
	"net/mail"
	"os"
	"os/exec"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"golang.org/x/sys/unix"
)

const (
	configDir = "/etc/cirrus-init"
)

func main() {
	ctx := context.Background()
	log.Println("Starting Cirrus Init!")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		log.Fatalf("Unable to create \"%s\": %v", configDir, err)
	}
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Printf("error: %v", err)
		return
	}
	client := imds.NewFromConfig(cfg)
	hostnameOutput, err := client.GetMetadata(ctx, &imds.GetMetadataInput{Path: "hostname"})
	if err != nil {
		log.Fatalf("Unable to retrieve the hostname from EC2 Instance Metadata: %v", err)
	}
	hostname, err := io.ReadAll(hostnameOutput.Content)
	if err != nil {
		log.Fatalf("Unable to read the hostname from EC2 Instance Metadata: %v", err)
	}
	unix.Sethostname(hostname)
	log.Printf("Set hostname to \"%s\"", hostname)
	userDataOutput, err := client.GetUserData(ctx, &imds.GetUserDataInput{})
	if err != nil {
		log.Fatalf("Unable to retrieve user-data: %v", err)
	}
	userData, err := io.ReadAll(userDataOutput.Content)
	if err != nil {
		log.Fatalf("Unable to read user-data: %v", err)
	}
	mimeReader, err := getMultiPartReader(string(userData))
	if err != nil {
		log.Fatalf("Unable to read mime formatted user-data: %v", err)
	}
	var userDataScripts []string
	i := 0
	for {
		i++
		part, err := mimeReader.NextPart()
		if errors.Is(err, io.EOF) {
			break
		}
		userDataPart, err := io.ReadAll(part)
		if err != nil {
			log.Fatalf("Unable to parse user-data part %d: %v", i, err)
		}
		userDataPartFile := fmt.Sprintf("%s/user-data-part-%d", configDir, i)
		if err := os.WriteFile(userDataPartFile, userDataPart, 0700); err != nil {
			log.Fatalf("Unable to write user-data part %d to file: %v", i, err)
		}
		userDataScripts = append(userDataScripts, userDataPartFile)
	}

	for _, scriptPath := range userDataScripts {
		if _, err := os.Stat(fmt.Sprintf("%s-finished", scriptPath)); err == nil {
			log.Printf("User Data script \"%s\" has already executed successfully.", scriptPath)
			continue
		}
		if err := exec.CommandContext(ctx, scriptPath).Run(); err != nil {
			log.Fatalf("Error executing \"%s\": %v", scriptPath, err)
		}
		if err := os.WriteFile(fmt.Sprintf("%s-finished", scriptPath), []byte{0}, 0644); err != nil {
			log.Fatalf("Unable to write \"finished\" file for %s: %v", scriptPath, err)
		}
	}

	fmt.Println("✅ Done")
}

func getMultiPartReader(userData string) (*multipart.Reader, error) {
	mailMsg, err := mail.ReadMessage(strings.NewReader(userData))
	if err != nil {
		return nil, fmt.Errorf("unreadable user data %w", err)
	}
	mediaType, params, err := mime.ParseMediaType(mailMsg.Header.Get("Content-Type"))
	if err != nil {
		return nil, fmt.Errorf("user data does not define a content-type header %w", err)
	}
	if !strings.HasPrefix(mediaType, "multipart/") {
		return nil, fmt.Errorf("user data is not in multipart MIME format")
	}
	return multipart.NewReader(mailMsg.Body, params["boundary"]), nil
}
