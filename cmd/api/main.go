package main

import (
	"log"
	"net/http"
	"time"

	ginzap "github.com/gin-contrib/zap"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/anthomm/golfstream/infrastructure/kafka"
	"github.com/anthomm/golfstream/internal/ingest"
)

func main() {

	r := gin.Default()
	logger, _ := zap.NewProduction()

	// Add a ginzap middleware, which:
	//   - Logs all requests, like a combined access and error log.
	//   - Logs to stdout.
	//   - RFC3339 with UTC time format.
	r.Use(ginzap.Ginzap(logger, time.RFC3339, true))

	// Logs all panic to error log
	//   - stack means whether output the stack info.
	r.Use(ginzap.RecoveryWithZap(logger, true))

	// Ingest slice
	kafkaProducer, err := kafka.NewKafkaProducer(
		[]string{"localhost:9094"},
		"hc",
		logger,
	)
	if err != nil {
		log.Fatalf("failed to create kafka producer: %v", err)
	}
	defer kafkaProducer.Close()

	ingestHandler := ingest.NewHandler(kafkaProducer, logger)
	ingestHandler.Register(r)

	// Define a simple GET endpoint
	r.GET("/ping", func(c *gin.Context) {
		// Return JSON response
		c.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})

	r.GET("/panic", func(c *gin.Context) {
		panic("An unexpected error happen!")
	})

	// Start server on port 8080 (default)
	if err := r.Run(); err != nil {
		log.Fatalf("failed to run server: %v", err)
	}
}
