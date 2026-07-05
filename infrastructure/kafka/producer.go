package kafka

import (
	"context"
	"fmt"

	"github.com/anthomm/golfstream/internal/ingest"
	"github.com/twmb/franz-go/pkg/kgo"
	"go.uber.org/zap"
)

type Producer struct {
	client *kgo.Client
	topic  string
	log    *zap.Logger
}

func NewKafkaProducer(brokers []string, topic string, log *zap.Logger) (*Producer, error) {
	client, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.DefaultProduceTopic(topic),
	)
	if err != nil {
		return nil, fmt.Errorf("kafka: create client: %w", err)
	}

	return &Producer{
		client: client,
		topic:  topic,
		log:    log,
	}, nil
}

func (p *Producer) Produce(ctx context.Context, cmd ingest.Command) error {
	record := &kgo.Record{
		Topic: p.topic,
		Value: cmd.Payload,
	}

	results := p.client.ProduceSync(ctx, record)
	if err := results.FirstErr(); err != nil {
		return fmt.Errorf("kafka: produce: %w", err)
	}

	rec := results[0].Record
	p.log.Info("kafka: message produced",
		zap.String("topic", rec.Topic),
		zap.Int32("partition", rec.Partition),
		zap.Int64("offset", rec.Offset),
	)

	return nil
}

func (p *Producer) Close() {
	p.client.Close()
}
