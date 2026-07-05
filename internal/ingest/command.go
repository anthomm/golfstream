package ingest

import "encoding/json"

type Command struct {
	Payload json.RawMessage
}
