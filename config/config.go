package config

import (
	"fmt"
	"os"
)

type DBConfig struct {
	Host     string
	User     string
	Password string
	Name     string
	Port     string
	SSLMode  string
}

func LoadDBConfig() *DBConfig {
	return &DBConfig{
		Host:     os.Getenv("PGHOST"),
		User:     os.Getenv("PGUSER"),
		Password: os.Getenv("PGPASSWORD"),
		Name:     os.Getenv("PGDATABASE"),
		Port:     os.Getenv("PGPORT"),
		SSLMode:  os.Getenv("PGSSLMODE"),
	}
}

func (c *DBConfig) DSN() string {
	return fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		c.Host, c.User, c.Password, c.Name, c.Port, c.SSLMode,
	)
}
