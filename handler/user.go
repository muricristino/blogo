package handler


import (
	"github.com/labstack/echo/v4"
	"github.com/olliefr/docker-gs-ping-roach/service"
	"github.com/olliefr/docker-gs-ping-roach/repository"
)

type UserHandler struct {
	Service service.UserService
}

func NewUserHandler(s service.UserService) *UserHandler {
	return &UserHandler{Service: s}
}

func (h *UserHandler) GetUsers(c echo.Context) error {
	users, err := h.Service.GetAllUsers()
	if err != nil {
		return echo.NewHTTPError(500, err.Error())
	}
	return c.JSON(200, users)
}

func (h *UserHandler) CreateUser(c echo.Context) error {
       u := new(repository.User)

       if err := c.Bind(u); err != nil {
	       return err
       }

       if err := c.Validate(u); err != nil {
	       return echo.NewHTTPError(422, err.Error())
       }

       err := h.Service.CreateUser(u)
       if err != nil {
	       return echo.NewHTTPError(500, err.Error())
       }

       return c.JSON(201, u)
}
