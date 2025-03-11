package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/hambosto/wallpaper-manager/internal/ui"
)

func main() {
	defaultWallpaperDir := filepath.Join(os.Getenv("HOME"), "Pictures")

	if _, err := os.Stat(defaultWallpaperDir); os.IsNotExist(err) {
		fmt.Printf("Default directory %s doesn't exist. Using current directory.\n", defaultWallpaperDir)
		defaultWallpaperDir, _ = os.Getwd()
	}

	app := ui.NewApp(defaultWallpaperDir)
	app.Run()
}
