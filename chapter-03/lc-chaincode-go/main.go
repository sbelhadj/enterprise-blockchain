package main

import (
	"log"

	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

func main() {
	cc, err := contractapi.NewChaincode(&LetterOfCreditContract{})
	if err != nil {
		log.Panicf("creating chaincode: %v", err)
	}
	if err := cc.Start(); err != nil {
		log.Panicf("starting chaincode: %v", err)
	}
}
