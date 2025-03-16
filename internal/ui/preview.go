package ui

import (
	"context"
	"image"
	"os"
	"runtime"
	"sync"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"github.com/disintegration/imaging"
	"github.com/hambosto/wallpaper-manager/internal/model"
	"golang.org/x/sync/semaphore"
)

type CachedImage struct {
	Image     image.Image
	Timestamp time.Time
	Size      int64
}

type ImageCache struct {
	cache       map[string]*CachedImage
	mutex       sync.RWMutex
	maxSize     int64
	currentSize int64
	sem         *semaphore.Weighted
	lruList     []string
	cleanupTick *time.Ticker
}

func NewImageCache(maxSizeMB int, maxConcurrent int64) *ImageCache {
	cache := &ImageCache{
		cache:       make(map[string]*CachedImage),
		maxSize:     int64(maxSizeMB) * 1024 * 1024,
		currentSize: 0,
		sem:         semaphore.NewWeighted(maxConcurrent),
		lruList:     make([]string, 0),
		cleanupTick: time.NewTicker(5 * time.Minute),
	}

	go cache.periodicCleanup()

	return cache
}

func (c *ImageCache) periodicCleanup() {
	for range c.cleanupTick.C {
		c.cleanup(30 * time.Minute)
	}
}

func (c *ImageCache) cleanup(maxAge time.Duration) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	now := time.Now()
	keysToRemove := []string{}

	for key, img := range c.cache {
		if now.Sub(img.Timestamp) > maxAge {
			keysToRemove = append(keysToRemove, key)
		}
	}

	for _, key := range keysToRemove {
		c.removeFromLRU(key)
		imgSize := c.cache[key].Size
		delete(c.cache, key)
		c.currentSize -= imgSize
	}
}

func (c *ImageCache) Get(path string) (*CachedImage, bool) {
	c.mutex.RLock()
	defer c.mutex.RUnlock()

	if img, exists := c.cache[path]; exists {
		c.updateLRU(path)
		img.Timestamp = time.Now()
		return img, true
	}
	return nil, false
}

func (c *ImageCache) Set(path string, img image.Image) {
	if img == nil {
		return
	}

	bounds := img.Bounds()
	width, height := bounds.Dx(), bounds.Dy()
	imgSize := int64(width * height * 4)

	c.mutex.Lock()
	defer c.mutex.Unlock()

	for c.currentSize+imgSize > c.maxSize && len(c.lruList) > 0 {
		c.evictOldest()
	}

	cachedImg := &CachedImage{
		Image:     img,
		Timestamp: time.Now(),
		Size:      imgSize,
	}

	c.cache[path] = cachedImg
	c.currentSize += imgSize
	c.lruList = append([]string{path}, c.lruList...)
}

func (c *ImageCache) evictOldest() {
	if len(c.lruList) == 0 {
		return
	}

	oldest := c.lruList[len(c.lruList)-1]
	imgSize := c.cache[oldest].Size
	delete(c.cache, oldest)
	c.lruList = c.lruList[:len(c.lruList)-1]
	c.currentSize -= imgSize

	if imgSize > 10*1024*1024 {
		runtime.GC()
	}
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

func (c *ImageCache) removeFromLRU(path string) {
	for i, p := range c.lruList {
		if p == path {
			c.lruList = append(c.lruList[:i], c.lruList[i+1:]...)
			break
		}
	}
}

func (c *ImageCache) Clear() {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	c.cache = make(map[string]*CachedImage)
	c.lruList = make([]string, 0)
	c.currentSize = 0
	runtime.GC()
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
	maxPreviewSize   int
	ctx              context.Context
	cancelLoading    context.CancelFunc
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

	ctx, cancel := context.WithCancel(context.Background())

	pm := &PreviewManager{
		previewContainer: mainContainer,
		imageContainer:   imageContainer,
		placeholderImg:   placeholderImg,
		loadingText:      loadingText,
		loadingProgress:  loadingProgress,
		imageCache:       NewImageCache(200, 3),
		updateChan:       make(chan previewUpdate, 2),
		maxPreviewSize:   1200,
		ctx:              ctx,
		cancelLoading:    cancel,
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

func (p *PreviewManager) UpdatePreview(wallpaper *model.Wallpaper) {
	if wallpaper == nil {
		p.ClearPreview()
		return
	}

	if p.currentPath == wallpaper.Path {
		return
	}

	p.cancelLoading()
	ctx, cancel := context.WithCancel(context.Background())
	p.ctx = ctx
	p.cancelLoading = cancel

	p.currentPath = wallpaper.Path

	p.loadingText.Show()
	p.loadingProgress.SetValue(0.0)
	p.loadingProgress.Show()
	p.previewContainer.Refresh()

	if cached, exists := p.imageCache.Get(wallpaper.Path); exists {
		p.displayCachedImage(cached.Image, wallpaper.Path)
		return
	}

	go p.loadAndCacheImage(wallpaper.Path, ctx)
}

func (p *PreviewManager) displayCachedImage(img image.Image, path string) {
	canvasImg := canvas.NewImageFromImage(img)
	canvasImg.FillMode = canvas.ImageFillContain
	canvasImg.ScaleMode = canvas.ImageScaleSmooth
	p.updateChan <- previewUpdate{img: canvasImg, path: path}
}

func (p *PreviewManager) loadAndCacheImage(path string, ctx context.Context) {
	if err := p.imageCache.sem.Acquire(ctx, 1); err != nil {
		return
	}
	defer p.imageCache.sem.Release(1)

	select {
	case <-ctx.Done():
		return
	default:
	}

	dimensions, err := getImageDimensions(path)
	if err != nil {
		return
	}

	img, err := p.loadOptimizedImage(path, dimensions)
	if err != nil || img == nil {
		return
	}

	select {
	case <-ctx.Done():
		img = nil
		runtime.GC()
		return
	default:
	}

	p.imageCache.Set(path, img)

	if p.currentPath == path {
		p.displayCachedImage(img, path)
	}
}

func (p *PreviewManager) loadOptimizedImage(path string, dimensions image.Point) (image.Image, error) {
	if dimensions.X > p.maxPreviewSize*2 || dimensions.Y > p.maxPreviewSize*2 {
		return p.loadDownsampledImage(path, dimensions)
	}

	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return nil, err
	}

	if dimensions.X > p.maxPreviewSize || dimensions.Y > p.maxPreviewSize {
		img = imaging.Fit(img, p.maxPreviewSize, p.maxPreviewSize, imaging.Lanczos)
	}

	return img, nil
}

func (p *PreviewManager) loadDownsampledImage(path string, dimensions image.Point) (image.Image, error) {
	var targetWidth, targetHeight int
	aspectRatio := float64(dimensions.X) / float64(dimensions.Y)

	if dimensions.X > dimensions.Y {
		targetWidth = p.maxPreviewSize
		targetHeight = int(float64(targetWidth) / aspectRatio)
	} else {
		targetHeight = p.maxPreviewSize
		targetWidth = int(float64(targetHeight) * aspectRatio)
	}

	img, err := imaging.Open(path)
	if err != nil {
		return nil, err
	}

	resized := imaging.Resize(img, targetWidth, targetHeight, imaging.Box)

	img = nil
	runtime.GC()

	return resized, nil
}

func getImageDimensions(path string) (image.Point, error) {
	file, err := os.Open(path)
	if err != nil {
		return image.Point{}, err
	}
	defer file.Close()

	config, _, err := image.DecodeConfig(file)
	if err != nil {
		return image.Point{}, err
	}

	return image.Point{X: config.Width, Y: config.Height}, nil
}

func (p *PreviewManager) ClearPreview() {
	p.cancelLoading()
	ctx, cancel := context.WithCancel(context.Background())
	p.ctx = ctx
	p.cancelLoading = cancel

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

func (p *PreviewManager) Cleanup() {
	p.cancelLoading()
	p.imageCache.Clear()
	p.imageCache.cleanupTick.Stop()
	close(p.updateChan)
}
