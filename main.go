package main

import (
	"net/http"
	"os"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/olliefr/docker-gs-ping-roach/handler"
)

func main() {
	e := echo.New()
	e.Use(middleware.Logger())

	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, Worldo!\n")
	})

	handler.RegisterRoutes(e)

	httpPort := os.Getenv("HTTP_PORT")

	if httpPort == "" {
		httpPort = "8080"
	}

	if err := e.Start(":" + httpPort); err != nil {
		e.Logger.Fatal(err)
	}
}
