package engine

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"

	"flsteamlua/lan_transfer_engine/internal/model"
)

func TestSenderStopsPendingApprovalAndCanOfferAgain(t *testing.T) {
	for _, action := range []struct {
		name   string
		method string
		status string
	}{
		{name: "pause", method: "session.pause", status: "paused"},
		{name: "cancel", method: "session.cancel", status: "cancelled"},
	} {
		t.Run(action.name, func(t *testing.T) {
			sender, receiver, library, lua := newTransferPair(t)
			value := transferFixturePlan(t, sender, 2)
			if _, err := sender.startSend(value.ID, "receiver", nil); err != nil {
				t.Fatal(err)
			}
			offer := waitForOffer(t, receiver)
			if _, err := sender.Execute(action.method, mustJSON(t, map[string]any{"sessionId": offer.SessionID})); err != nil {
				t.Fatal(err)
			}
			awaitPendingApprovalStopped(t, receiver, offer.SessionID, action.status)
			if _, err := os.Stat(filepath.Join(library, "steamapps", "common", "Fixture")); !os.IsNotExist(err) {
				t.Fatal("unapproved transfer installed game content")
			}
			if action.status == "paused" {
				if _, err := sender.resumeSession(offer.SessionID); err != nil {
					t.Fatal(err)
				}
			} else {
				value = transferFixturePlan(t, sender, 2)
				if _, err := sender.startSend(value.ID, "receiver", nil); err != nil {
					t.Fatal(err)
				}
			}
			approveAndVerifyFixture(t, sender, receiver, library, lua, value)
		})
	}
}

func TestDisconnectedPendingApprovalCanResume(t *testing.T) {
	sender, receiver, library, lua := newTransferPair(t)
	value := transferFixturePlan(t, sender, 2)
	if _, err := sender.startSend(value.ID, "receiver", nil); err != nil {
		t.Fatal(err)
	}
	offer := waitForOffer(t, receiver)
	runtime := sender.session(offer.SessionID)
	runtime.mu.Lock()
	conn := runtime.conn
	runtime.mu.Unlock()
	conn.close()
	awaitPendingApprovalStopped(t, receiver, offer.SessionID, "failed")
	awaitTransfer(t, sender, offer.SessionID, func(value model.Session) bool { return value.Status == "failed" })
	runtime.mu.Lock()
	done := runtime.done
	runtime.mu.Unlock()
	if done != nil {
		<-done
	}
	if _, err := sender.resumeSession(offer.SessionID); err != nil {
		t.Fatal(err)
	}
	approveAndVerifyFixture(t, sender, receiver, library, lua, value)
}

func awaitPendingApprovalStopped(t *testing.T, receiver *Engine, id, status string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		receiver.mu.Lock()
		pending := receiver.pending[id]
		runtime := receiver.sessions[id]
		receiver.mu.Unlock()
		runtime.mu.Lock()
		stopped := runtime.done == nil && runtime.data.Status == status
		runtime.mu.Unlock()
		if pending == nil && stopped {
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("pending approval did not stop as %s: %+v", status, receiver.sessionSnapshot(id))
}

func approveAndVerifyFixture(t *testing.T, sender, receiver *Engine, library, lua string, value *model.Plan) {
	t.Helper()
	offer := waitForOffer(t, receiver)
	if _, err := receiver.acceptOffer(offer.SessionID, library, lua, false); err != nil {
		t.Fatal(err)
	}
	final := awaitTransfer(t, sender, offer.SessionID, func(value model.Session) bool {
		return value.Status == "completed" || value.Status == "failed"
	})
	if final.Status != "completed" {
		t.Fatalf("new offer failed after previous approval stopped: %+v", final)
	}
	got, err := os.ReadFile(filepath.Join(library, "steamapps", "common", "Fixture", "payload.bin"))
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile(value.Files[0].SourcePath)
	if err != nil || !bytes.Equal(got, want) {
		t.Fatal("new offer lost the prefetched plan or transferred incorrect content")
	}
}
