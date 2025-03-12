package ui

import (
	"image"
	"os"
	"sync"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"github.com/hambosto/wallpaper-manager/internal/model"
)

type ImageCache struct {
	cache map[string]image.Image
	mutex sync.RWMutex
}

func NewImageCache() *ImageCache {
	return &ImageCache{
		cache: make(map[string]image.Image),
	}
}

func (c *ImageCache) Get(path string) (image.Image, bool) {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	img, exists := c.cache[path]
	return img, exists
}

func (c *ImageCache) Set(path string, img image.Image) {
	c.mutex.Lock()
	defer c.mutex.Unlock()
	c.cache[path] = img
}

type PreviewManager struct {
	previewContainer *fyne.Container
	imageContainer   *fyne.Container
	placeholderImg   *canvas.Text
	loadingText      *canvas.Text
	loadingProgress  *widget.ProgressBar
	imageCache       *ImageCache
	currentPath      string
	updateChan       chan *canvas.Image
	onceMap          sync.Map
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
		imageCache:       NewImageCache(),
		updateChan:       make(chan *canvas.Image, 1),
	}

	go pm.handleUpdates()

	return pm
}

func (p *PreviewManager) handleUpdates() {
	for img := range p.updateChan {
		time.AfterFunc(time.Millisecond*10, func() {
			p.imageContainer.RemoveAll()
			p.imageContainer.Add(img)
			p.loadingText.Hide()
			p.loadingProgress.Hide()
			p.previewContainer.Refresh()
		})
	}
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

	if cachedImg, exists := p.imageCache.Get(wallpaper.Path); exists {
		p.displayCachedImage(cachedImg)
		return
	}

	once, _ := p.onceMap.LoadOrStore(wallpaper.Path, &sync.Once{})
	once.(*sync.Once).Do(func() {
		go p.loadAndCacheImage(wallpaper.Path)
	})
}

func (p *PreviewManager) displayCachedImage(img image.Image) {
	go func() {
		canvasImg := canvas.NewImageFromImage(img)
		canvasImg.FillMode = canvas.ImageFillContain
		canvasImg.ScaleMode = canvas.ImageScaleSmooth
		p.updateChan <- canvasImg
	}()
}

func (p *PreviewManager) loadAndCacheImage(path string) {
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
		p.displayCachedImage(img)
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
