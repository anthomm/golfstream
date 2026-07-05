package ingest

import "context"

type Producer interface {
	Produce(ctx context.Context, cmd Command) error
}
