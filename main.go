package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/olliefr/docker-gs-ping-roach/handler"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func Blogo(database *gorm.DB) *echo.Echo {
	e := echo.New()
	e.Use(middleware.Logger())
	handler.RegisterRoutes(e, database)

	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, corcavado!\n")
	})

	r := mux.NewRouter()
	r.HandleFunc("/mux/hello", func(w http.ResponseWriter, req *http.Request) {
		w.Write([]byte("Hello from gorilla/mux!\n"))
	})

	e.Any("/mux/*", echo.WrapHandler(r))

	return e
}

func main() {
	var err error

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		os.Getenv("PGHOST"),
		os.Getenv("PGUSER"),
		os.Getenv("PGPASSWORD"),
		os.Getenv("PGDATABASE"),
		os.Getenv("PGPORT"),
		os.Getenv("PGSSLMODE"),
	)

	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Printf("Falha ao conectar no banco de dados via GORM: %v", err)
	} else {
		log.Println("Conectado ao CockroachDB com sucesso via GORM!")
		DB.AutoMigrate(&handler.User{})
	}

	e := Blogo(DB)

	httpPort := os.Getenv("HTTP_PORT")
	if httpPort == "" {
		httpPort = "8080"
	}

	if err := e.Start(":" + httpPort); err != nil {
		e.Logger.Fatal(err)
	}
}