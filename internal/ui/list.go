package ui

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/storage"
	"fyne.io/fyne/v2/widget"
	"github.com/hambosto/wallpaper-manager/internal/model"
	"github.com/hambosto/wallpaper-manager/internal/service"
)

type ListManager struct {
	wallpaperService  *service.WallpaperService
	wallpapers        []model.Wallpaper
	wallpaperList     *widget.List
	selectedID        int
	onSelectionChange func(int)
}

func NewListManager(wallpaperServ *service.WallpaperService, onSelectionChange func(int)) *ListManager {
	lm := &ListManager{
		wallpaperService:  wallpaperServ,
		wallpapers:        []model.Wallpaper{},
		selectedID:        -1,
		onSelectionChange: onSelectionChange,
	}

	lm.wallpaperList = widget.NewList(
		func() int {
			return len(lm.wallpapers)
		},
		func() fyne.CanvasObject {
			return widget.NewLabel("Template")
		},
		func(id widget.ListItemID, item fyne.CanvasObject) {
			item.(*widget.Label).SetText(lm.wallpapers[id].Name)
		},
	)

	lm.wallpaperList.OnSelected = func(id widget.ListItemID) {
		lm.selectedID = id
		if lm.onSelectionChange != nil {
			lm.onSelectionChange(id)
		}
	}

	return lm
}

func (l *ListManager) LoadWallpapers() error {
	wallpapers, err := l.wallpaperService.GetWallpapers()
	if err != nil {
		return err
	}
	l.wallpapers = wallpapers
	l.wallpaperList.Refresh()

	return nil
}

func (l *ListManager) GetWallpaper(index int) *model.Wallpaper {
	if index >= 0 && index < len(l.wallpapers) {
		return &l.wallpapers[index]
	}
	return nil
}

func (l *ListManager) GetSelectedWallpaper() *model.Wallpaper {
	return l.GetWallpaper(l.selectedID)
}

func (l *ListManager) SelectWallpaper(index int) {
	if index >= 0 && index < len(l.wallpapers) {
		l.wallpaperList.Select(index)
	}
}

func (l *ListManager) GetWallpaperCount() int {
	return len(l.wallpapers)
}

func (l *ListManager) GetListWidget() *widget.List {
	return l.wallpaperList
}

func (l *ListManager) ShowFolderDialog(parent fyne.Window, onSelect func(string)) {
	folderDialog := dialog.NewFolderOpen(func(uri fyne.ListableURI, err error) {
		if err != nil {
			ShowErrorDialog(parent, err.Error())
			return
		}
		if uri == nil {
			return
		}

		path := uri.Path()
		if onSelect != nil {
			onSelect(path)
		}
	}, parent)

	startDir, _ := storage.ListerForURI(storage.NewFileURI(l.wallpaperService.WallpaperDir))
	if startDir != nil {
		folderDialog.SetLocation(startDir)
	}

	folderDialog.Show()
}
