package repository

import (
	"gorm.io/gorm"
)

type User struct {
	ID   uint   `gorm:"primaryKey" json:"id"`
	Name string `json:"name" validate:"required"`
	Age  int    `json:"age"`
}

type UserRepository interface {
	FindAll() ([]User, error)
	Create(user *User) error
}

type userRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository {
	return &userRepository{db}
}

func (r *userRepository) FindAll() ([]User, error) {
	var users []User
	err := r.db.Find(&users).Error
	return users, err
}

func (r *userRepository) Create(user *User) error {
	return r.db.Create(user).Error
}
