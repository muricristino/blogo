package service

import (
	"github.com/olliefr/docker-gs-ping-roach/repository"
)

type UserService interface {
	GetAllUsers() ([]repository.User, error)
	CreateUser(user *repository.User) error
}

type userService struct {
	repo repository.UserRepository
}

func NewUserService(repo repository.UserRepository) UserService {
	return &userService{repo}
}

func (s *userService) GetAllUsers() ([]repository.User, error) {
	return s.repo.FindAll()
}

func (s *userService) CreateUser(user *repository.User) error {
	return s.repo.Create(user)
}
