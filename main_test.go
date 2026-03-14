package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

)

func TestRootEndpoint(t *testing.T) {
	e := Blogo()

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()

	e.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("esperado status %d, obtido %d", http.StatusOK, rec.Code)
	}

	expected := "Hello, corcavado!\n"
	if rec.Body.String() != expected {
		t.Errorf("esperado corpo %q, obtido %q", expected, rec.Body.String())
	}
}