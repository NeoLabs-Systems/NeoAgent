package slack

import "encoding/base64"

func base64Std(s string) string { return base64.StdEncoding.EncodeToString([]byte(s)) }
