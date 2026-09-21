package main

import (
	"log"
	"github.com/olliefr/docker-gs-ping-roach/config"
	"github.com/olliefr/docker-gs-ping-roach/repository"
	"github.com/olliefr/docker-gs-ping-roach/service"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/olliefr/docker-gs-ping-roach/handler"
)

var DB *gorm.DB

func Blogo(userService service.UserService) *echo.Echo {
	e := echo.New()
	e.Use(middleware.Logger())
	       handler.RegisterRoutes(e, userService)

	       e.GET("/", func(c echo.Context) error {
		       return c.String(200, "Hello, corcavado!\n")
	       })

	       return e
	}

	func main() {
		var err error

		dbConfig := config.LoadDBConfig()
		dsn := dbConfig.DSN()

		DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err != nil {
			log.Printf("Falha ao conectar no banco de dados via GORM: %v", err)
		} else {
			log.Println("Conectado ao CockroachDB com sucesso via GORM!")
			DB.AutoMigrate(&repository.User{})
		}

		userRepo := repository.NewUserRepository(DB)
		userService := service.NewUserService(userRepo)
		e := Blogo(userService)

		httpPort := dbConfig.Port
		if httpPort == "" {
			httpPort = "8080"
		}

		if err := e.Start(":" + httpPort); err != nil {
			e.Logger.Fatal(err)
		}
	}