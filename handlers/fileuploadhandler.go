package handlers

import (
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path"
	"time"

	"../utils"
	"github.com/gorilla/mux"
)

// UploadHandler handles for http upload
type FileUploadHandler struct {
	BaseDir string
}

func (u *FileUploadHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	utils.GetUploadLogger().Infof("Received upload request\n")
	curFileURL := req.URL.EscapedPath()[len("/ldash"):]
	vars := mux.Vars(req)
	folder := vars["folder"]
	curFolderPath := path.Join(u.BaseDir, folder)
	curFilePath := path.Join(u.BaseDir, curFileURL)
	u.serveHTTPImpl(curFolderPath, curFilePath, w, req)
}

func (u *FileUploadHandler) serveHTTPImpl(curFolderPath string, curFilePath string, w http.ResponseWriter, req *http.Request) {
	if _, err := os.Stat(curFolderPath); os.IsNotExist(err) {
		err := os.MkdirAll(curFolderPath, os.ModePerm)
		if err != nil {
			utils.GetUploadLogger().Infof("fail to create file %v", err)
		}
	}

	// rewrite, mostly for manifest file
	if _, err := os.Stat(curFilePath); err == nil {
		utils.GetUploadLogger().Debugf("rewrite file %s @ %v \n", curFilePath, time.Now().Format(time.RFC3339))
		data, _ := ioutil.ReadAll(req.Body)
		err = ioutil.WriteFile(curFilePath, data, 0644)
		if err != nil {
			utils.GetUploadLogger().Errorf("fail to create file %v \n", err)
		}
		return
	}

	// create, mostly for segment
	// for segment, we will allow partial downloading during the uploading to save the time for player(this is what low latency meaning)
	// So here uses Symlink as a signal to tell download handler whether the uploading is finished or not.
        symlink := curFilePath + ".symlink"
        os.Symlink(curFilePath, symlink)
        utils.GetUploadLogger().Debugf("create symlink %s @ %v \n", symlink, time.Now().Format(time.RFC3339))


	f, rerr := os.Create(curFilePath)
	if rerr != nil {
		utils.GetUploadLogger().Errorf("fail to create file %s : %v\n", curFilePath, rerr)
		return
	}

	utils.GetUploadLogger().Debugf("create file %s @ %v \n", curFilePath, time.Now().Format(time.RFC3339))
	defer f.Close()

	_, rerr = io.Copy(f, req.Body)
	if rerr != nil {
		utils.GetUploadLogger().Errorf("fail to create file %v \n", rerr)
	}

	// remove symlink once the uploading is done
	os.Remove(symlink)
	utils.GetUploadLogger().Debugf("remove symlink %s @ %v \n", symlink, time.Now().Format(time.RFC3339))

}
