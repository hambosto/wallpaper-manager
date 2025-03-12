package service

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/hambosto/wallpaper-manager/internal/model"
)

type WallpaperService struct {
	WallpaperDir string
}

func NewWallpaperService(wallpaperDir string) *WallpaperService {
	return &WallpaperService{
		WallpaperDir: wallpaperDir,
	}
}

func (s *WallpaperService) GetWallpapers() ([]model.Wallpaper, error) {
	var wallpapers []model.Wallpaper
	files, err := os.ReadDir(s.WallpaperDir)
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		if !file.IsDir() {
			ext := strings.ToLower(filepath.Ext(file.Name()))
			if ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".gif" {
				wallpapers = append(wallpapers, model.Wallpaper{
					Name: file.Name(),
					Path: filepath.Join(s.WallpaperDir, file.Name()),
				})
			}
		}
	}
	return wallpapers, nil
}

func (s *WallpaperService) SetWallpaper(path string) error {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	cacheFile := filepath.Join(os.Getenv("HOME"), ".cache", ".active_wallpaper")

	cacheDir := filepath.Dir(cacheFile)
	if err := os.MkdirAll(cacheDir, 0o755); err != nil {
		return err
	}

	if err := os.WriteFile(cacheFile, []byte(absPath), 0o644); err != nil {
		return err
	}

	cmd := exec.Command("swww", "img", absPath, "--transition-type", "random")
	return cmd.Run()
}

func (s *WallpaperService) UpdateWallpaperDirectory(newDir string) {
	s.WallpaperDir = newDir
}
