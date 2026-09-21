package handler

import "github.com/labstack/echo/v4"

import (
	"github.com/olliefr/docker-gs-ping-roach/service"
)

func RegisterRoutes(e *echo.Echo, userService service.UserService) {
	userHandler := NewUserHandler(userService)

	e.GET("/users", userHandler.GetUsers)
	e.POST("/users", userHandler.CreateUser)
}
