package utils

import (
	"os"
	"path/filepath"
)

// RemoveContents remove the all files in the work folder at beginning
func RemoveContents(dir string) error {
	d, err := os.Open(dir)
	if err != nil {
		return err
	}
	defer d.Close()
	names, err := d.Readdirnames(-1)
	if err != nil {
		GetGCloadLogger().Errorf("%v\n", err)
		return err
	}
	for _, name := range names {
		err = os.RemoveAll(filepath.Join(dir, name))
		if err != nil {
			GetGCloadLogger().Errorf("%v\n", err)
			return err
		}
	}
	return nil
}
