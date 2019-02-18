package main

import (
	"flag"
	"log"
	"net/http"
	"path/filepath"
	"time"

	"./handlers"
	"./utils"
	"github.com/gorilla/mux"
)

func main() {
	flag.Parse()
	args := flag.Args()
	if len(args) != 1 || args[0] == "" {
		utils.GetMainLogger().Errorf("Usage: need base dir\n")
		return
	}

	filePath, err := filepath.Abs(args[0])
	if err != nil {
		utils.GetMainLogger().Errorf("Cannot resolve this path %s\n", filePath)
		return
	}

	utils.GetMainLogger().Infof("baseDir %v \n", filePath)

	// clean the segment folder
	utils.RemoveContents(args[0])

	file_downloadHandler := &handlers.FileDownloadHandler{
		StartTime: time.Now(),
		BaseDir:   filePath,
	}

	file_uploadHandler := &handlers.FileUploadHandler{
		BaseDir: filePath,
	}

	dash_playHandler := &handlers.DashPlayHandler{
		BaseDir: filePath,
	}

	file_deleteHandler := &handlers.FileDeleteHandler{
		BaseDir: filePath,
	}

	r := mux.NewRouter()
	r.Handle("/ldash/{folder}/{name:[a-zA-Z0-9/_-]+}.{name:[a-zA-Z0-9/_-]+}", file_uploadHandler).Methods("PUT", "POST")
	r.Handle("/ldash/{folder}/{name:[a-zA-Z0-9/_-]+}.{name:[a-zA-Z0-9/_-]+}", file_downloadHandler).Methods("GET")
	r.Handle("/ldash/{folder}/{name:[a-zA-Z0-9/_-]+}.{name:[a-zA-Z0-9/_-]+}", file_deleteHandler).Methods("DELETE")
	r.Handle("/ldashplay/{folder}/{name:[a-zA-Z0-9/_-]+}.{name:[a-zA-Z0-9/_-]+}", dash_playHandler)

	utils.GetMainLogger().Infof("start server\n")
	log.Fatal(http.ListenAndServe(":8080", r))
}
