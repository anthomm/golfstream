package ingest

import (
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type Handler struct {
	producer Producer
	log      *zap.Logger
}

func NewHandler(producer Producer, log *zap.Logger) *Handler {
	return &Handler{producer: producer, log: log}
}

func (h *Handler) Register(r *gin.Engine) {
	r.POST("/events", h.handle)
}

func (h *Handler) handle(c *gin.Context) {
	var payload json.RawMessage
	if err := c.ShouldBindJSON(&payload); err != nil {
		h.log.Warn("invalid json payload", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON"})
		return
	}

	cmd := Command{Payload: payload}
	if err := h.producer.Produce(c.Request.Context(), cmd); err != nil {
		h.log.Error("failed to produce event", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to persist event"})
		return
	}

	c.Status(http.StatusOK)
}
