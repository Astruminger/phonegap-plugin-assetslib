var assetslib = {

	getAllPhotos:function(successCallback, errorCallback) {
		cordova.exec(successCallback, errorCallback, "AssetsLib", "getAllPhotos", []);
	},
	
    getFullScreenPhotos:function(urlList, successCallback, errorCallback) {
		cordova.exec(successCallback, errorCallback, "AssetsLib", "getFullScreenPhotos", [urlList]);
	},

	getPhotoMetadata:function(urlList, successCallback, errorCallback) {
		cordova.exec(successCallback, errorCallback, "AssetsLib", "getPhotoMetadata", [urlList]);
	}
    
    
}	

module.exports = assetslib;