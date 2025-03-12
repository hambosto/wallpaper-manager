package ui

import (
	"context"
	"image"
	"image/gif"
	"os"
	"sync"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"github.com/hambosto/wallpaper-manager/internal/model"
	"golang.org/x/sync/semaphore"
)

type ImageCache struct {
	cache   map[string]interface{}
	mutex   sync.RWMutex
	maxSize int
	sem     *semaphore.Weighted
	lruList []string
}

func NewImageCache(maxSize int, maxConcurrent int64) *ImageCache {
	return &ImageCache{
		cache:   make(map[string]interface{}),
		maxSize: maxSize,
		sem:     semaphore.NewWeighted(maxConcurrent),
		lruList: make([]string, 0, maxSize),
	}
}

func (c *ImageCache) Get(path string) (interface{}, bool) {
	c.mutex.RLock()
	defer c.mutex.RUnlock()

	if img, exists := c.cache[path]; exists {
		c.updateLRU(path)
		return img, true
	}
	return nil, false
}

func (c *ImageCache) Set(path string, img interface{}) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	if len(c.cache) >= c.maxSize {
		oldest := c.lruList[len(c.lruList)-1]
		delete(c.cache, oldest)
		c.lruList = c.lruList[:len(c.lruList)-1]
	}

	c.cache[path] = img
	c.lruList = append([]string{path}, c.lruList...)
}

func (c *ImageCache) updateLRU(path string) {
	for i, p := range c.lruList {
		if p == path {
			copy(c.lruList[1:i+1], c.lruList[0:i])
			c.lruList[0] = path
			break
		}
	}
}

type PreviewManager struct {
	previewContainer *fyne.Container
	imageContainer   *fyne.Container
	placeholderImg   *canvas.Text
	loadingText      *canvas.Text
	loadingProgress  *widget.ProgressBar
	imageCache       *ImageCache
	currentPath      string
	updateChan       chan previewUpdate
}

type previewUpdate struct {
	img  *canvas.Image
	path string
}

func NewPreviewManager() *PreviewManager {
	placeholderImg := canvas.NewText("No preview available", theme.Color(theme.ColorNameBackground))
	placeholderImg.Alignment = fyne.TextAlignCenter

	loadingText := canvas.NewText("Loading...", theme.Color(theme.ColorNamePrimary))
	loadingText.Alignment = fyne.TextAlignCenter
	loadingText.Hide()

	loadingProgress := widget.NewProgressBar()
	loadingProgress.Hide()

	imageContainer := container.NewStack(placeholderImg)

	mainContainer := container.NewStack(
		imageContainer,
		container.NewVBox(loadingText, loadingProgress),
	)

	pm := &PreviewManager{
		previewContainer: mainContainer,
		imageContainer:   imageContainer,
		placeholderImg:   placeholderImg,
		loadingText:      loadingText,
		loadingProgress:  loadingProgress,
		imageCache:       NewImageCache(100, 5),
		updateChan:       make(chan previewUpdate, 2),
	}

	go pm.handleUpdates()

	return pm
}

func (p *PreviewManager) handleUpdates() {
	for update := range p.updateChan {
		if update.path != p.currentPath {
			continue
		}
		p.imageContainer.RemoveAll()
		p.imageContainer.Add(update.img)
		p.loadingText.Hide()
		p.loadingProgress.Hide()
		p.previewContainer.Refresh()
	}
}

func (p *PreviewManager) displayGIF(gifImg *gif.GIF, path string) {
	if len(gifImg.Image) == 0 {
		return
	}

	canvasImg := canvas.NewImageFromImage(gifImg.Image[0])
	canvasImg.FillMode = canvas.ImageFillContain
	canvasImg.ScaleMode = canvas.ImageScaleSmooth
	p.updateChan <- previewUpdate{img: canvasImg, path: path}
}

func (p *PreviewManager) UpdatePreview(wallpaper *model.Wallpaper) {
	if wallpaper == nil {
		p.ClearPreview()
		return
	}

	if p.currentPath == wallpaper.Path {
		return
	}

	p.currentPath = wallpaper.Path

	p.loadingText.Show()
	p.loadingProgress.SetValue(0.0)
	p.loadingProgress.Show()
	p.previewContainer.Refresh()

	if cached, exists := p.imageCache.Get(wallpaper.Path); exists {
		switch img := cached.(type) {
		case *gif.GIF:
			p.displayGIF(img, wallpaper.Path)
		case image.Image:
			p.displayCachedImage(img, wallpaper.Path)
		}
		return
	}

	go p.loadAndCacheImage(wallpaper.Path)
}

func (p *PreviewManager) displayCachedImage(img image.Image, path string) {
	canvasImg := canvas.NewImageFromImage(img)
	canvasImg.FillMode = canvas.ImageFillContain
	canvasImg.ScaleMode = canvas.ImageScaleSmooth
	p.updateChan <- previewUpdate{img: canvasImg, path: path}
}

func (p *PreviewManager) loadAndCacheImage(path string) {
	if err := p.imageCache.sem.Acquire(context.Background(), 1); err != nil {
		return
	}
	defer p.imageCache.sem.Release(1)

	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return
	}

	p.imageCache.Set(path, img)

	if p.currentPath == path {
		p.displayCachedImage(img, path)
	}
}

func (p *PreviewManager) ClearPreview() {
	p.currentPath = ""
	p.imageContainer.RemoveAll()
	p.imageContainer.Add(p.placeholderImg)
	p.loadingText.Hide()
	p.loadingProgress.Hide()
	p.previewContainer.Refresh()
}

func (p *PreviewManager) GetPreviewContainer() *fyne.Container {
	return p.previewContainer
}
