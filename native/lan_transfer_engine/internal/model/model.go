package model

type Config struct {
	DataDir               string   `json:"dataDir"`
	SteamPath             string   `json:"steamPath"`
	LuaRoot               string   `json:"luaRoot"`
	KeyCacheRoot          string   `json:"keyCacheRoot"`
	DisplayName           string   `json:"displayName"`
	ReceiveEnabled        bool     `json:"receiveEnabled"`
	AutoAcceptTrusted     bool     `json:"autoAcceptTrusted"`
	LibraryRoots          []string `json:"libraryRoots"`
	SkipSteamRunningCheck bool     `json:"skipSteamRunningCheck"`
}

type Peer struct {
	ID          string `json:"id"`
	Alias       string `json:"alias"`
	Address     string `json:"address"`
	Port        int    `json:"port"`
	Fingerprint string `json:"fingerprint"`
	Trusted     bool   `json:"trusted"`
	LastSeen    int64  `json:"lastSeen"`
}

type TrustedPeer struct {
	Fingerprint        string `json:"fingerprint"`
	Alias              string `json:"alias"`
	DefaultLibraryRoot string `json:"defaultLibraryRoot"`
	AutoAccept         bool   `json:"autoAccept"`
	LastSeen           int64  `json:"lastSeen"`
}

type GameInput struct {
	AppID       uint32 `json:"appId"`
	Name        string `json:"name"`
	InstallPath string `json:"installPath"`
	LibraryPath string `json:"libraryPath"`
	LuaPath     string `json:"luaPath"`
	LuaEnabled  bool   `json:"luaEnabled"`
	CoverURL    string `json:"coverUrl"`
	SizeOnDisk  int64  `json:"sizeOnDisk"`
}

type FileChunkRef struct {
	ChunkIndex uint32 `json:"chunkIndex"`
	Offset     int64  `json:"offset"`
	Size       int64  `json:"size"`
}

type PlanFile struct {
	ID             string         `json:"id"`
	RelativePath   string         `json:"relativePath"`
	Size           int64          `json:"size"`
	SHA1           string         `json:"sha1"`
	SHA256         string         `json:"sha256"`
	Category       string         `json:"category"`
	Selected       bool           `json:"selected"`
	SourceModified int64          `json:"sourceModified"`
	Chunks         []FileChunkRef `json:"-"`
	SourcePath     string         `json:"-"`
}

type Chunk struct {
	ID   string `json:"id"`
	Size int64  `json:"size"`
	SHA1 string `json:"sha1"`
	CRC  uint32 `json:"crc"`
}

type Plan struct {
	ID                  string     `json:"id"`
	AppID               uint32     `json:"appId"`
	GameName            string     `json:"gameName"`
	InstallDir          string     `json:"installDir"`
	CoverURL            string     `json:"coverUrl"`
	SourceAppManifest   string     `json:"-"`
	LuaContent          string     `json:"-"`
	LuaEnabled          bool       `json:"luaEnabled"`
	ManifestAvailable   bool       `json:"manifestAvailable"`
	TotalCandidateBytes int64      `json:"totalCandidateBytes"`
	Warnings            []string   `json:"warnings"`
	Files               []PlanFile `json:"-"`
	Chunks              []Chunk    `json:"-"`
	CreatedAt           int64      `json:"createdAt"`
}

type FileSummary struct {
	ID           string `json:"id"`
	RelativePath string `json:"relativePath"`
	Size         int64  `json:"size"`
	Category     string `json:"category"`
}

type PlanSummary struct {
	ID                string        `json:"id"`
	AppID             uint32        `json:"appId"`
	GameName          string        `json:"gameName"`
	InstallDir        string        `json:"installDir"`
	CoverURL          string        `json:"coverUrl"`
	LuaEnabled        bool          `json:"luaEnabled"`
	LuaAvailable      bool          `json:"luaAvailable"`
	ManifestAvailable bool          `json:"manifestAvailable"`
	SelectedBytes     int64         `json:"selectedBytes"`
	OfficialBytes     int64         `json:"officialBytes"`
	ManifestBytes     int64         `json:"manifestBytes"`
	OptionalBytes     int64         `json:"optionalBytes"`
	OfficialFiles     int           `json:"officialFiles"`
	ManifestFiles     int           `json:"manifestFiles"`
	ChunkCount        int           `json:"chunkCount"`
	Warnings          []string      `json:"warnings"`
	OptionalFiles     []FileSummary `json:"optionalFiles"`
}

type OfferSummary struct {
	SessionID         string   `json:"sessionId"`
	BundleID          string   `json:"bundleId"`
	AppID             uint32   `json:"appId"`
	GameName          string   `json:"gameName"`
	InstallDir        string   `json:"installDir"`
	CoverURL          string   `json:"coverUrl"`
	TotalBytes        int64    `json:"totalBytes"`
	SelectedBytes     int64    `json:"selectedBytes"`
	FileCount         int      `json:"fileCount"`
	ChunkCount        int      `json:"chunkCount"`
	LuaEnabled        bool     `json:"luaEnabled"`
	ManifestAvailable bool     `json:"manifestAvailable"`
	Warnings          []string `json:"warnings"`
	Peer              Peer     `json:"peer"`
	Trusted           bool     `json:"trusted"`
	ReceivedAt        int64    `json:"receivedAt"`
}

type Session struct {
	ID               string  `json:"id"`
	BundleID         string  `json:"bundleId"`
	AppID            uint32  `json:"appId"`
	GameName         string  `json:"gameName"`
	CoverURL         string  `json:"coverUrl"`
	Direction        string  `json:"direction"`
	PeerID           string  `json:"peerId"`
	PeerAlias        string  `json:"peerAlias"`
	PeerAddress      string  `json:"peerAddress"`
	PeerFingerprint  string  `json:"peerFingerprint"`
	Status           string  `json:"status"`
	TotalBytes       int64   `json:"totalBytes"`
	TransferredBytes int64   `json:"transferredBytes"`
	NetworkBytes     int64   `json:"networkBytes"`
	DiskBytes        int64   `json:"diskBytes"`
	DiskSpeed        float64 `json:"diskSpeed"`
	InstalledBytes   int64   `json:"installedBytes"`
	InstalledFiles   int     `json:"installedFiles"`
	TotalFiles       int     `json:"totalFiles"`
	Speed            float64 `json:"speed"`
	PeakSpeed        float64 `json:"peakSpeed"`
	Message          string  `json:"message"`
	Error            string  `json:"error,omitempty"`
	TargetLibrary    string  `json:"targetLibrary,omitempty"`
	CanPause         bool    `json:"canPause"`
	TotalChunks      int     `json:"totalChunks"`
	CompletedChunks  int     `json:"completedChunks"`
	CachedChunks     int     `json:"cachedChunks"`
	CreatedAt        int64   `json:"createdAt"`
}

type CacheStats struct {
	Bytes int64 `json:"bytes"`
	Files int64 `json:"files"`
}
