package handler

import (
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

type HandlerFunc func(db *gorm.DB, c echo.Context) error

func wrap(db *gorm.DB, handler HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		return handler(db, c)
	}
}

func RegisterRoutes(e *echo.Echo, database *gorm.DB) {
	e.GET("/users", wrap(database, GetUsers))
	e.POST("/users", wrap(database, CreateUser))
}
