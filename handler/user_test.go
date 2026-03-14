package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestGetUsers(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/users", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	if err := GetUsers(c); err != nil {
		t.Fatalf("GetUsers returned error: %v", err)
	}

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	expected := "[]\n"
	if rec.Body.String() != expected {
		t.Errorf("expected body %q, got %q", expected, rec.Body.String())
	}
}

func TestCreateUser(t *testing.T) {
	e := echo.New()
	body := `{"name":"Alice"}`
	req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	if err := CreateUser(c); err != nil {
		t.Fatalf("CreateUser returned error: %v", err)
	}

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d", http.StatusCreated, rec.Code)
	}

	expected := `{"name":"Alice"}` + "\n"
	if rec.Body.String() != expected {
		t.Errorf("expected body %q, got %q", expected, rec.Body.String())
	}
}

func TestCreateUserEmptyBody(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader("{}"))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	if err := CreateUser(c); err != nil {
		t.Fatalf("CreateUser returned error: %v", err)
	}

	if rec.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d", http.StatusCreated, rec.Code)
	}

	expected := `{"name":""}` + "\n"
	if rec.Body.String() != expected {
		t.Errorf("expected body %q, got %q", expected, rec.Body.String())
	}
}

func TestRegisterRoutes(t *testing.T) {
	e := echo.New()
	RegisterRoutes(e)

	routes := e.Routes()
	found := map[string]bool{
		"GET /users":  false,
		"POST /users": false,
	}

	for _, r := range routes {
		key := r.Method + " " + r.Path
		if _, ok := found[key]; ok {
			found[key] = true
		}
	}

	for key, registered := range found {
		if !registered {
			t.Errorf("expected route %q to be registered", key)
		}
	}
}
