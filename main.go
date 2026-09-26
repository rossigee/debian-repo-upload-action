package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

var version = "dev"

type UploadResponse struct {
	Package      string `json:"package"`
	Version      string `json:"version"`
	Architecture string `json:"architecture"`
	Filename     string `json:"filename"`
	Checksums    struct {
		SHA256 string `json:"sha256"`
	} `json:"checksums"`
	Status string `json:"status"`
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(flag.CommandLine.Output(), "debian-repo-upload-action %s\n\n", version)
		fmt.Fprintf(flag.CommandLine.Output(), "Usage: %s <file|files> <base-url> <token> [suite] [component] [fail-on-error]\n", os.Args[0])
	}

	flag.Parse()
	args := flag.Args()

	if len(args) < 3 {
		flag.Usage()
		os.Exit(1)
	}

	fileArg := args[0]
	filesArg := ""
	if len(args) > 0 && args[0] != "" {
		filesArg = ""
	}
	baseURL := args[1]
	token := args[2]
	suite := ""
	component := ""
	failOnError := "true"

	if len(args) > 3 {
		suite = args[3]
	}
	if len(args) > 4 {
		component = args[4]
	}
	if len(args) > 5 {
		failOnError = args[5]
	}

	// Validate inputs
	if baseURL == "" {
		fatalf("base-url input is required")
	}
	if token == "" {
		fatalf("token input is required")
	}

	if !strings.HasPrefix(baseURL, "http://") && !strings.HasPrefix(baseURL, "https://") {
		fatalf("base-url must start with http:// or https://")
	}

	baseURL = strings.TrimSuffix(baseURL, "/")

	// Collect files to upload
	files, err := expandGlobPatterns(fileArg, filesArg)
	if err != nil {
		fatalf("failed to expand glob patterns: %v", err)
	}

	if len(files) == 0 {
		fatalf("no matching files found")
	}

	// Validate all files exist and are readable
	if err := validateFiles(files); err != nil {
		fatalf("file validation failed: %v", err)
	}

	// Upload files
	successCount, failureCount := uploadFiles(files, baseURL, token, suite, component, failOnError)

	// Print summary
	fmt.Println()
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("Upload Summary: ✅ %d succeeded\n", successCount)
	if failureCount > 0 {
		fmt.Printf("               ❌ %d failed\n", failureCount)
		if failOnError == "true" {
			os.Exit(1)
		}
	}
	fmt.Println()
}

func expandGlobPatterns(file, files string) ([]string, error) {
	var results []string
	seen := make(map[string]bool)

	if file != "" {
		expanded, err := filepath.Glob(file)
		if err != nil {
			return nil, fmt.Errorf("invalid glob pattern '%s': %w", file, err)
		}
		if len(expanded) == 0 {
			return nil, fmt.Errorf("file glob pattern '%s' matched no files", file)
		}
		for _, f := range expanded {
			if !seen[f] {
				results = append(results, f)
				seen[f] = true
			}
		}
		return results, nil
	}

	if files != "" {
		patterns := strings.FieldsFunc(files, func(r rune) bool {
			return r == ' ' || r == ','
		})
		for _, pattern := range patterns {
			pattern = strings.TrimSpace(pattern)
			expanded, err := filepath.Glob(pattern)
			if err != nil {
				return nil, fmt.Errorf("invalid glob pattern '%s': %w", pattern, err)
			}
			if len(expanded) == 0 {
				return nil, fmt.Errorf("files glob pattern '%s' matched no files", pattern)
			}
			for _, f := range expanded {
				if !seen[f] {
					results = append(results, f)
					seen[f] = true
				}
			}
		}
	}

	return results, nil
}

func validateFiles(files []string) error {
	for _, file := range files {
		info, err := os.Stat(file)
		if err != nil {
			if os.IsNotExist(err) {
				return fmt.Errorf("file '%s' not found", file)
			}
			return fmt.Errorf("cannot stat '%s': %w", file, err)
		}

		if info.IsDir() {
			return fmt.Errorf("'%s' is a directory, not a file", file)
		}

		if !isReadable(file) {
			return fmt.Errorf("file '%s' is not readable", file)
		}

		if info.Size() > 536870912 { // 512MB
			return fmt.Errorf("file '%s' is too large (%dMB, max 512MB)", file, info.Size()/1024/1024)
		}
	}
	return nil
}

func isReadable(path string) bool {
	file, err := os.Open(path)
	if err != nil {
		return false
	}
	file.Close()
	return true
}

func uploadFiles(files []string, baseURL, token, suite, component, failOnError string) (int, int) {
	success := 0
	failure := 0

	fmt.Println()
	for _, file := range files {
		fmt.Printf("⬆️  Uploading %s...\n", filepath.Base(file))

		uploadURL := baseURL + "/api/v1/upload"

		// Add query parameters
		params := url.Values{}
		if suite != "" {
			params.Set("suite", suite)
		}
		if component != "" {
			params.Set("component", component)
		}
		if params.Encode() != "" {
			uploadURL = uploadURL + "?" + params.Encode()
		}

		// Upload file
		if err := uploadFile(file, uploadURL, token); err != nil {
			fmt.Fprintf(os.Stderr, "   ❌ %v\n", err)
			failure++
			if failOnError == "true" {
				os.Exit(1)
			}
			continue
		}

		success++
	}

	return success, failure
}

func uploadFile(filepath, uploadURL, token string) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	req, err := http.NewRequest("POST", uploadURL, file)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("upload failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	var uploadResp UploadResponse
	if err := json.Unmarshal(body, &uploadResp); err != nil {
		return fmt.Errorf("invalid JSON response: %w", err)
	}

	if uploadResp.Status != "registered" {
		fmt.Fprintf(os.Stderr, "   ⚠️  Expected status 'registered', got '%s'\n", uploadResp.Status)
	}

	// Write to GITHUB_OUTPUT
	if githubOutput := os.Getenv("GITHUB_OUTPUT"); githubOutput != "" {
		f, err := os.OpenFile(githubOutput, os.O_APPEND|os.O_WRONLY, 0644)
		if err == nil {
			defer f.Close()
			fmt.Fprintf(f, "package=%s\n", uploadResp.Package)
			fmt.Fprintf(f, "version=%s\n", uploadResp.Version)
			fmt.Fprintf(f, "architecture=%s\n", uploadResp.Architecture)
			fmt.Fprintf(f, "filename=%s\n", uploadResp.Filename)
			fmt.Fprintf(f, "sha256=%s\n", uploadResp.Checksums.SHA256)
			fmt.Fprintf(f, "status=%s\n", uploadResp.Status)
		}
	}

	fmt.Printf("   ✅ %s %s (%s)\n", uploadResp.Package, uploadResp.Version, uploadResp.Architecture)
	return nil
}

func fatalf(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "❌ Error: "+format+"\n", args...)
	os.Exit(1)
}
