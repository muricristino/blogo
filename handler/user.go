package handler

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

type User struct {
	ID   uint   `gorm:"primaryKey" json:"id"`
	Name string `json:"name" validate:"required"`
	Age int `json:"age"`
}

func GetUsers(db *gorm.DB, c echo.Context) error {
	var users []User
	if db != nil {
		db.Find(&users)
	}

	return c.JSON(http.StatusOK, users)
}

func CreateUser(db *gorm.DB, c echo.Context) error {
	u := new(User)

	if err := c.Bind(u); err != nil {
		return err
	}

	if err := c.Validate(u); err != nil {
		return echo.NewHTTPError(http.StatusUnprocessableEntity, err.Error())
	}

	if db != nil {
		db.Create(u)
	}

	return c.JSON(http.StatusCreated, u)
}
