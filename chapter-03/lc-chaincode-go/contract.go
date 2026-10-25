// SPDX-License-Identifier: Apache-2.0

// Package main is the Go version of the letter of credit chaincode's IssueLC and ReadLC
// (Book 4, Section 3.11). The TypeScript version in ../lc-chaincode is the complete one.
package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"

	"github.com/hyperledger/fabric-chaincode-go/v2/pkg/statebased"
	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

// LetterOfCredit mirrors the TypeScript asset. Go's encoding/json writes struct fields in
// declaration order, so serialization is deterministic without extra libraries.
type LetterOfCredit struct {
	DocType       string `json:"docType"`
	ID            string `json:"id"`
	Applicant     string `json:"applicant"`
	Beneficiary   string `json:"beneficiary"`
	IssuingBank   string `json:"issuingBank"`
	AdvisingBank  string `json:"advisingBank"`
	Amount        int64  `json:"amount"` // minor units
	Currency      string `json:"currency"`
	ExpiryDate    string `json:"expiryDate"`
	Goods         string `json:"goods"`
	DocumentsHash string `json:"documentsHash"`
	Status        string `json:"status"`
	IssuedAt      string `json:"issuedAt"`
	UpdatedAt     string `json:"updatedAt"`
}

// LetterOfCreditContract holds the chaincode functions.
type LetterOfCreditContract struct {
	contractapi.Contract
}

var (
	idPattern       = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)
	amountPattern   = regexp.MustCompile(`^[1-9][0-9]{0,14}$`)
	currencyPattern = regexp.MustCompile(`^[A-Z]{3}$`)
)

// IssueLC opens a letter of credit. The caller must hold lc.role=issuer.
func (c *LetterOfCreditContract) IssueLC(ctx contractapi.TransactionContextInterface,
	id, applicant, beneficiary, advisingBank string,
	amount, currency, expiryDate, goods string) error {
	if err := ctx.GetClientIdentity().AssertAttributeValue("lc.role", "issuer"); err != nil {
		return fmt.Errorf("only an LC officer (lc.role=issuer) may issue a letter of credit")
	}
	issuingBank, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return err
	}
	if !idPattern.MatchString(id) || !amountPattern.MatchString(amount) ||
		!currencyPattern.MatchString(currency) {
		return fmt.Errorf("invalid id, amount or currency")
	}
	if advisingBank == "" || advisingBank == issuingBank {
		return fmt.Errorf("the advising bank must be another organization")
	}
	ts, err := ctx.GetStub().GetTxTimestamp() // never time.Now(): endorsers would disagree
	if err != nil {
		return err
	}
	now := ts.AsTime().UTC().Format("2006-01-02T15:04:05.000Z")
	if expiryDate <= now[:10] {
		return fmt.Errorf("expiry date %s is not after the transaction date %s",
			expiryDate, now[:10])
	}
	existing, err := ctx.GetStub().GetState(id)
	if err != nil {
		return err
	}
	if existing != nil {
		return fmt.Errorf("letter of credit %s already exists", id)
	}
	value, _ := strconv.ParseInt(amount, 10, 64)
	lc := LetterOfCredit{DocType: "lc", ID: id, Applicant: applicant, Beneficiary: beneficiary,
		IssuingBank: issuingBank, AdvisingBank: advisingBank, Amount: value, Currency: currency,
		ExpiryDate: expiryDate, Goods: goods, Status: "ISSUED", IssuedAt: now, UpdatedAt: now}
	data, err := json.Marshal(lc)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(id, data); err != nil {
		return err
	}
	policy, err := statebased.NewStateEP(nil)
	if err != nil {
		return err
	}
	if err := policy.AddOrgs(statebased.RoleTypePeer, issuingBank, advisingBank); err != nil {
		return err
	}
	ep, err := policy.Policy()
	if err != nil {
		return err
	}
	return ctx.GetStub().SetStateValidationParameter(id, ep)
}

// ReadLC returns one letter of credit.
func (c *LetterOfCreditContract) ReadLC(ctx contractapi.TransactionContextInterface,
	id string) (*LetterOfCredit, error) {
	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, err
	}
	if data == nil {
		return nil, fmt.Errorf("letter of credit %s does not exist", id)
	}
	var lc LetterOfCredit
	if err := json.Unmarshal(data, &lc); err != nil {
		return nil, err
	}
	return &lc, nil
}
