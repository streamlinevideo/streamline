package utils

import (
	"os"

	"github.com/juju/loggo"
	"github.com/juju/loggo/loggocolor"
)

func getLogger(scope string) loggo.Logger {
	logger := loggo.GetLogger(scope)
	logger.SetLogLevel(loggo.DEBUG)
	loggo.ReplaceDefaultWriter(loggocolor.NewWriter(os.Stderr))

	return logger
}

func GetMainLogger() loggo.Logger {
	return getLogger("Main")
}

func GetUploadLogger() loggo.Logger {
	return getLogger("Upload")
}

func GetDownloadLogger() loggo.Logger {
	return getLogger("Download")
}

func GetPlayerLogger() loggo.Logger {
	return getLogger("Player")
}

func GetDeleteLogger() loggo.Logger {
	return getLogger("Delete")
}

func GetGCloadLogger() loggo.Logger {
	return getLogger("GC")
}
