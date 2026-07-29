#!/usr/bin/env bash
# Builds the pre-pr-review eval fixture: a small Go repo with a feature branch
# whose diff plants one violation for each of CNV's four questions, plus
# material for SIM. Kept as a script because a committed git repo would nest
# inside dotfiles and be treated as a submodule.
#
# Usage: bash setup-reco.sh <target-dir>
#   base branch: main   feature branch: feature/criteria-proposal
#
# What is planted (do not "fix" these — the evals depend on them):
#   置き場  CriteriaProposalIDDAO is a one-method DAO returning job-offer IDs,
#           which existing JobOfferIDDAO already collects.
#   層      CriteriaSchemaVersion (an application decision) sits in infrastructure.
#   型      proposalTarget.JobOfferID is int; every other ID is uint.
#   命名    Row type is MLJobOfferCriteriaProposal but CriteriaItem / proposalMeta
#           lack the ML prefix.
#   SIM     A 3-attempt retry loop nothing asks for; an ORDER BY no caller depends
#           on; a payload temp variable used once; Insert ignores its meta argument.
#   その他   docs/design/criteria_proposal.md is background material, not a review
#           item. The test file's helper is used only inside its own file.
set -euo pipefail

DEST="${1:?usage: bash setup-reco.sh <target-dir>}"
rm -rf "$DEST"
mkdir -p "$DEST"/{domain,application/usecase,infrastructure/dao,docs/design}
cd "$DEST"

cat > go.mod <<'EOF'
module example.com/reco

go 1.22

require (
	github.com/go-sql-driver/mysql v1.8.1
	gorm.io/gorm v1.25.10
)
EOF

cat > CLAUDE.md <<'EOF'
# reco 開発規約

## レイヤ
- `domain/`: ドメインの語彙と業務ルール。**アプリケーションが決める値の定義元はここに置く。**
- `application/`: ユースケース。domain と infrastructure を組み合わせるだけ。
- `infrastructure/`: DB・外部 API。DB のデフォルト値やスキーマの写像だけを持ち、業務上の判断は持たない。

## 型
- ID はすべて `uint`。DB のカラムが signed でも、コード上は uint に揃える。

## DAO
- 集約1つにつき DAO 1つ。同じ集約の ID を引くクエリは既存 DAO に足す（1メソッドだけの DAO を新設しない）。
- テーブル行を表す型は `<接頭辞><テーブル名>` 形式。同じテーブルに属する型は接頭辞を共有する。

## テスト
- `go test ./...`
EOF

cat > domain/job_offer.go <<'EOF'
package domain

type JobOfferID uint

type JobOffer struct {
	ID       JobOfferID
	Title    string
	IsActive bool
}
EOF

cat > infrastructure/dao/job_offer_id_dao.go <<'EOF'
package dao

import (
	"context"

	"gorm.io/gorm"

	"example.com/reco/domain"
)

// JobOfferIDDAO は求人 ID を引くクエリを集めた DAO。
type JobOfferIDDAO struct {
	db *gorm.DB
}

func NewJobOfferIDDAO(db *gorm.DB) *JobOfferIDDAO {
	return &JobOfferIDDAO{db: db}
}

func (d *JobOfferIDDAO) ListActiveIDs(ctx context.Context) ([]domain.JobOfferID, error) {
	var ids []domain.JobOfferID
	if err := d.db.WithContext(ctx).
		Table("job_offers").
		Where("is_active = ?", true).
		Pluck("id", &ids).Error; err != nil {
		return nil, err
	}
	return ids, nil
}
EOF

cat > application/usecase/list_active_job_offers.go <<'EOF'
package usecase

import (
	"context"

	"example.com/reco/domain"
	"example.com/reco/infrastructure/dao"
)

type ListActiveJobOffers struct {
	ids *dao.JobOfferIDDAO
}

func NewListActiveJobOffers(ids *dao.JobOfferIDDAO) *ListActiveJobOffers {
	return &ListActiveJobOffers{ids: ids}
}

func (u *ListActiveJobOffers) Run(ctx context.Context) ([]domain.JobOfferID, error) {
	return u.ids.ListActiveIDs(ctx)
}
EOF

git init -q -b main
git config user.email fixture@example.com
git config user.name Fixture
git add -A
git commit -qm "feat: 求人 ID の一覧取得"

git checkout -q -b feature/criteria-proposal

cat > docs/design/criteria_proposal.md <<'EOF'
# 求人条件の提案（criteria proposal）設計メモ

## 確定済みの判断
- 提案は LLM に生成させ、生成結果はそのまま保存する（人手の補正は入れない）。
- 提案の保存形式は JSON カラム1本にまとめる。カラム分割はしない。
- スキーマ版番号を提案レコードに持たせ、読み出し側が版番号で分岐する。

## 用語
- 提案（proposal）: 1求人に対する条件案のまとまり。
- 条件項目（criteria item）: 提案の中の1項目。年収・勤務地などの軸ごとに1つ。

## 処理の流れ
1. 対象求人 ID を集める。
2. 求人ごとに LLM を呼び、条件項目の配列を得る。
3. 提案レコードとして保存する。
EOF

cat > infrastructure/dao/criteria_proposal_id_dao.go <<'EOF'
package dao

import (
	"context"

	"gorm.io/gorm"

	"example.com/reco/domain"
)

type CriteriaProposalIDDAO struct {
	db *gorm.DB
}

func NewCriteriaProposalIDDAO(db *gorm.DB) *CriteriaProposalIDDAO {
	return &CriteriaProposalIDDAO{db: db}
}

func (d *CriteriaProposalIDDAO) ListTargetJobOfferIDs(ctx context.Context, limit int) ([]domain.JobOfferID, error) {
	var ids []domain.JobOfferID
	if err := d.db.WithContext(ctx).
		Table("job_offers").
		Where("is_active = ?", true).
		Order("created_at DESC").
		Limit(limit).
		Pluck("id", &ids).Error; err != nil {
		return nil, err
	}
	return ids, nil
}
EOF

cat > infrastructure/dao/ml_job_offer_criteria_proposal.go <<'EOF'
package dao

import (
	"context"
	"encoding/json"
	"time"

	"gorm.io/gorm"
)

// CriteriaSchemaVersion は提案レコードのスキーマ版番号。
const CriteriaSchemaVersion = 3

type MLJobOfferCriteriaProposal struct {
	ID            uint      `gorm:"primaryKey"`
	JobOfferID    uint      `gorm:"column:job_offer_id"`
	Payload       string    `gorm:"column:payload"`
	SchemaVersion int       `gorm:"column:schema_version"`
	CreatedAt     time.Time `gorm:"column:created_at"`
}

func (MLJobOfferCriteriaProposal) TableName() string {
	return "ml_job_offer_criteria_proposals"
}

type CriteriaItem struct {
	Axis  string `json:"axis"`
	Value string `json:"value"`
}

type proposalMeta struct {
	Model    string `json:"model"`
	Attempts int    `json:"attempts"`
}

func NewProposalMeta(model string, attempts int) proposalMeta {
	return proposalMeta{Model: model, Attempts: attempts}
}

type MLJobOfferCriteriaProposalDAO struct {
	db *gorm.DB
}

func NewMLJobOfferCriteriaProposalDAO(db *gorm.DB) *MLJobOfferCriteriaProposalDAO {
	return &MLJobOfferCriteriaProposalDAO{db: db}
}

func (d *MLJobOfferCriteriaProposalDAO) Insert(ctx context.Context, jobOfferID uint, items []CriteriaItem, meta proposalMeta) error {
	encoded, err := json.Marshal(items)
	if err != nil {
		return err
	}
	payload := string(encoded)

	row := MLJobOfferCriteriaProposal{
		JobOfferID:    jobOfferID,
		Payload:       payload,
		SchemaVersion: CriteriaSchemaVersion,
	}

	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		lastErr = d.db.WithContext(ctx).Create(&row).Error
		if lastErr == nil {
			return nil
		}
	}
	return lastErr
}
EOF

cat > application/usecase/propose_criteria.go <<'EOF'
package usecase

import (
	"context"
	"fmt"

	"example.com/reco/domain"
	"example.com/reco/infrastructure/dao"
)

type LLMClient interface {
	ProposeCriteria(ctx context.Context, title string) ([]dao.CriteriaItem, error)
}

type proposalTarget struct {
	JobOfferID int
	Title      string
}

type ProposeCriteria struct {
	targets   *dao.CriteriaProposalIDDAO
	proposals *dao.MLJobOfferCriteriaProposalDAO
	llm       LLMClient
}

func NewProposeCriteria(
	targets *dao.CriteriaProposalIDDAO,
	proposals *dao.MLJobOfferCriteriaProposalDAO,
	llm LLMClient,
) *ProposeCriteria {
	return &ProposeCriteria{targets: targets, proposals: proposals, llm: llm}
}

func (u *ProposeCriteria) Run(ctx context.Context, limit int) error {
	ids, err := u.targets.ListTargetJobOfferIDs(ctx, limit)
	if err != nil {
		return err
	}

	for _, id := range ids {
		target := proposalTarget{
			JobOfferID: int(id),
			Title:      u.titleOf(id),
		}

		items, err := u.llm.ProposeCriteria(ctx, target.Title)
		if err != nil {
			return fmt.Errorf("propose criteria: %w", err)
		}

		if err := u.proposals.Insert(ctx, uint(target.JobOfferID), items, dao.NewProposalMeta("gpt", 1)); err != nil {
			return err
		}
	}
	return nil
}

func (u *ProposeCriteria) titleOf(id domain.JobOfferID) string {
	return fmt.Sprintf("job offer %d", uint(id))
}
EOF

cat > infrastructure/dao/ml_job_offer_criteria_proposal_test.go <<'EOF'
package dao

import "testing"

func newTestItems(axes ...string) []CriteriaItem {
	items := make([]CriteriaItem, 0, len(axes))
	for _, axis := range axes {
		items = append(items, CriteriaItem{Axis: axis, Value: "x"})
	}
	return items
}

func TestTableName(t *testing.T) {
	if got := MLJobOfferCriteriaProposal{}.TableName(); got != "ml_job_offer_criteria_proposals" {
		t.Fatalf("unexpected table name: %s", got)
	}
}

func TestNewTestItems(t *testing.T) {
	if len(newTestItems("salary", "location")) != 2 {
		t.Fatal("want 2 items")
	}
}
EOF

git add -A
git commit -qm "feat: 求人条件の提案を保存する"

echo "fixture ready: $DEST (main...feature/criteria-proposal)"
git diff main...HEAD --stat
