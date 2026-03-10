package handler

import "github.com/labstack/echo/v4"

func RegisterRoutes(e *echo.Echo) {
	e.GET("/users", GetUsers)
	e.POST("/users", CreateUser)
}
