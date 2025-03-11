package ui

import (
	"fmt"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
	"github.com/hambosto/wallpaper-manager/internal/service"
)

type App struct {
	fyneApp          fyne.App
	mainWindow       fyne.Window
	wallpaperService *service.WallpaperService
	previewManager   *PreviewManager
	listManager      *ListManager
	statusLabel      *widget.Label
	folderLabel      *widget.Label
}

func NewApp(defaultWallpaperDir string) *App {
	fyneApp := app.New()
	mainWindow := fyneApp.NewWindow("SWWW Wallpaper Selector")
	mainWindow.Resize(fyne.NewSize(1000, 600))

	statusLabel := widget.NewLabel("Loading wallpapers...")
	folderLabel := widget.NewLabel(fmt.Sprintf("Current folder: %s", defaultWallpaperDir))

	wallpaperServ := service.NewWallpaperService(defaultWallpaperDir)

	return &App{
		fyneApp:          fyneApp,
		mainWindow:       mainWindow,
		wallpaperService: wallpaperServ,
		statusLabel:      statusLabel,
		folderLabel:      folderLabel,
	}
}

func (a *App) Run() {
	a.previewManager = NewPreviewManager()

	a.listManager = NewListManager(a.wallpaperService, func(wp int) {
		a.updateStatusText(fmt.Sprintf("Selected wallpaper %d", wp))
		a.previewManager.UpdatePreview(a.listManager.GetWallpaper(wp))
	})

	a.refreshWallpapers()

	setBtn := a.createSetButton()
	changeFolderBtn := a.createChangeFolderButton()
	refreshBtn := a.createRefreshButton()

	leftPanel := container.NewBorder(
		container.NewVBox(
			widget.NewLabel("Wallpapers:"),
			a.folderLabel,
			changeFolderBtn,
		),
		container.NewVBox(
			setBtn,
			refreshBtn,
		),
		nil,
		nil,
		container.NewVScroll(a.listManager.GetListWidget()),
	)

	rightPanel := container.NewBorder(
		widget.NewLabel("Preview:"),
		nil,
		nil,
		nil,
		a.previewManager.GetPreviewContainer(),
	)

	split := container.NewHSplit(
		leftPanel,
		rightPanel,
	)
	split.Offset = 0.3

	content := container.NewBorder(
		nil,
		container.NewVBox(
			widget.NewSeparator(),
			a.statusLabel,
		),
		nil,
		nil,
		split,
	)

	a.mainWindow.SetContent(content)
	a.mainWindow.ShowAndRun()
}

func (a *App) createSetButton() *widget.Button {
	return widget.NewButton("Set as Wallpaper", func() {
		if selectedWP := a.listManager.GetSelectedWallpaper(); selectedWP != nil {
			a.updateStatusText(fmt.Sprintf("Setting wallpaper: %s", selectedWP.Name))

			err := a.wallpaperService.SetWallpaper(selectedWP.Path)
			if err != nil {
				a.showError(fmt.Sprintf("Error setting wallpaper: %v", err))
			} else {
				a.updateStatusText(fmt.Sprintf("Wallpaper set: %s", selectedWP.Name))
			}
		}
	})
}

func (a *App) createChangeFolderButton() *widget.Button {
	return widget.NewButton("Change Folder", func() {
		a.listManager.ShowFolderDialog(a.mainWindow, func(newPath string) {
			a.wallpaperService.UpdateWallpaperDirectory(newPath)
			a.folderLabel.SetText(fmt.Sprintf("Current folder: %s", newPath))

			a.refreshWallpapers()

			a.updateStatusText(fmt.Sprintf("Changed folder to: %s", newPath))
		})
	})
}

func (a *App) createRefreshButton() *widget.Button {
	return widget.NewButton("Refresh", func() {
		a.refreshWallpapers()
	})
}

func (a *App) refreshWallpapers() {
	a.updateStatusText("Loading wallpapers...")
	err := a.listManager.LoadWallpapers()

	if err != nil {
		a.showError(fmt.Sprintf("Error loading wallpapers: %v", err))
	} else {
		wallpaperCount := a.listManager.GetWallpaperCount()
		a.updateStatusText(fmt.Sprintf("Found %d wallpapers", wallpaperCount))

		if wallpaperCount > 0 {
			a.listManager.SelectWallpaper(0)
		} else {
			a.previewManager.ClearPreview()
		}
	}
}

func (a *App) updateStatusText(text string) {
	a.statusLabel.SetText(text)
}

func (a *App) showError(message string) {
	a.updateStatusText(message)
	ShowErrorDialog(a.mainWindow, message)
}
