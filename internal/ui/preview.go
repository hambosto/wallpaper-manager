package ui

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"github.com/hambosto/wallpaper-manager/internal/model"
)

type PreviewManager struct {
	previewContainer *fyne.Container
	placeholderImg   *canvas.Text
}

func NewPreviewManager() *PreviewManager {
	placeholderImg := canvas.NewText("No preview available", theme.Color(theme.ColorNameBackground))
	placeholderImg.Alignment = fyne.TextAlignCenter

	previewContainer := container.NewStack()
	previewContainer.Add(placeholderImg)

	return &PreviewManager{
		previewContainer: previewContainer,
		placeholderImg:   placeholderImg,
	}
}

func (p *PreviewManager) UpdatePreview(wallpaper *model.Wallpaper) {
	if wallpaper == nil {
		p.ClearPreview()
		return
	}

	p.previewContainer.RemoveAll()

	img := canvas.NewImageFromFile(wallpaper.Path)
	img.FillMode = canvas.ImageFillContain
	img.ScaleMode = canvas.ImageScaleSmooth

	p.previewContainer.Add(img)
	p.previewContainer.Refresh()
}

func (p *PreviewManager) ClearPreview() {
	p.previewContainer.RemoveAll()
	p.previewContainer.Add(p.placeholderImg)
	p.previewContainer.Refresh()
}

func (p *PreviewManager) GetPreviewContainer() *fyne.Container {
	return p.previewContainer
}
