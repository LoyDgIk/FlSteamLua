package identity

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Identity struct {
	Certificate tls.Certificate
	PEM         []byte
	Fingerprint string
}

func LoadOrCreate(directory, displayName string) (*Identity, error) {
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return nil, err
	}
	keyPath := filepath.Join(directory, "identity.key")
	certPath := filepath.Join(directory, "identity.crt")
	keyPEM, keyErr := os.ReadFile(keyPath)
	certPEM, certErr := os.ReadFile(certPath)
	if keyErr != nil || certErr != nil {
		key, cert, err := create(displayName)
		if err != nil {
			return nil, err
		}
		if err := os.WriteFile(keyPath, key, 0o600); err != nil {
			return nil, err
		}
		if err := os.WriteFile(certPath, cert, 0o600); err != nil {
			return nil, err
		}
		keyPEM, certPEM = key, cert
	}
	certificate, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		return nil, fmt.Errorf("load identity: %w", err)
	}
	if len(certificate.Certificate) == 0 {
		return nil, fmt.Errorf("identity certificate is empty")
	}
	sum := sha256.Sum256(certificate.Certificate[0])
	return &Identity{
		Certificate: certificate,
		PEM:         certPEM,
		Fingerprint: strings.ToUpper(hex.EncodeToString(sum[:])),
	}, nil
}

func create(displayName string) (keyPEM, certPEM []byte, err error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, nil, err
	}
	serialLimit := new(big.Int).Lsh(big.NewInt(1), 128)
	serial, err := rand.Int(rand.Reader, serialLimit)
	if err != nil {
		return nil, nil, err
	}
	name := displayName
	if strings.TrimSpace(name) == "" {
		name = "FlSteamLua"
	}
	now := time.Now()
	template := &x509.Certificate{
		SerialNumber:          serial,
		Subject:               pkix.Name{CommonName: name, Organization: []string{"FlSteamLua"}},
		NotBefore:             now.Add(-24 * time.Hour),
		NotAfter:              now.AddDate(10, 0, 0),
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth, x509.ExtKeyUsageClientAuth},
		BasicConstraintsValid: true,
		IsCA:                  false,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return nil, nil, err
	}
	keyBytes, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return nil, nil, err
	}
	keyPEM = pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyBytes})
	certPEM = pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	return keyPEM, certPEM, nil
}

func FingerprintDER(der []byte) string {
	sum := sha256.Sum256(der)
	return strings.ToUpper(hex.EncodeToString(sum[:]))
}

func (i *Identity) ServerConfig() *tls.Config {
	return &tls.Config{
		MinVersion:   tls.VersionTLS13,
		Certificates: []tls.Certificate{i.Certificate},
		ClientAuth:   tls.RequireAnyClientCert,
	}
}

func (i *Identity) ClientConfig(expectedFingerprint string) *tls.Config {
	expected := strings.ToUpper(strings.TrimSpace(expectedFingerprint))
	return &tls.Config{
		MinVersion:         tls.VersionTLS13,
		Certificates:       []tls.Certificate{i.Certificate},
		InsecureSkipVerify: true,
		VerifyConnection: func(state tls.ConnectionState) error {
			if len(state.PeerCertificates) == 0 {
				return fmt.Errorf("peer did not present a certificate")
			}
			actual := FingerprintDER(state.PeerCertificates[0].Raw)
			if expected != "" && actual != expected {
				return fmt.Errorf("peer certificate fingerprint mismatch")
			}
			return nil
		},
	}
}

func PeerFingerprint(state tls.ConnectionState) string {
	if len(state.PeerCertificates) == 0 {
		return ""
	}
	return FingerprintDER(state.PeerCertificates[0].Raw)
}

func (i *Identity) CertificatePEM() string {
	return string(i.PEM)
}
