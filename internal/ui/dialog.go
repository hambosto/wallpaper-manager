package ui

import (
	"errors"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/dialog"
)

func ShowErrorDialog(parent fyne.Window, message string) {
	dialog.ShowError(errors.New(message), parent)
}
