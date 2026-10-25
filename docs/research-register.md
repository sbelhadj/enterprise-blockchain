# Book 4 Research Register
*Enterprise Blockchain Revolution: Harnessing Hyperledger Fabric for Business Transformation*
*Phase 2 results | Sami BELHADJ | 24 October 2026*
## 1 Summary
Phase 2 checked the 18 candidate cases in the plan and the technical, standards and regulatory items marked [VERIFY]. All sources were read on 24 October 2026; each fact below carries the source it comes from. Technical facts were checked against the Fabric 3.1.5 documentation and source code, the release notes, and the installed packages, rather than against secondary articles.
- **Cases.** 16 of the 18 cases are kept. 10 are confirmed as Fabric deployments from a primary or Fabric-project source. The other six stay as labeled contrasts or context: Komgo (Quorum, still operating), Contour and Marco Polo (Corda, both closed), the ASX CHESS replacement (built by Digital Asset, cancelled), BIS Project Agora (platform not stated), and MediLedger and Everledger (platform not named in the sources found). ProCredEx and Tracr are dropped because no source names their platform. Two confirmed Fabric cases were added: IBM Digital Health Pass and the Botanical Water Exchange.
- **Draft errors confirmed.** Komgo did not shut down: in November 2025 it reported more than 10,000 corporate users and connections with more than 60 banks, on Quorum. Contour closed on 30 November 2023 and Marco Polo entered insolvency in March 2023, not in 2022. Walmart's mango trace went from 7 days to 2.2 seconds, not "six days and eighteen hours".
- **New corrections for the book.** Fabric 3.0 deprecated block dissemination by gossip: peers now receive blocks directly from the ordering service by default, which changes the leader-peer explanation in the Chapter 2 draft. The Fabric release binaries are built without PKCS#11, so the HSM exercise needs a peer built from source.
- **Chapter cases fixed.** Section 4 assigns four cases to each chapter, one per sector.

## 2 Cases Verified

**Table 1: Cases kept, with verified facts**

| Case | Sector | Platform | Verified facts | Source |
|---|---|---|---|---|
| we.trade | Finance | Hyperledger Fabric | Set up in 2017 by 12 banks; IBM took a 7% stake in 2020; announced it was shutting down and proposed PwC as liquidator in June 2022; technology licensed to 16 banks in 15 countries | FinTech Futures, 13 June 2022 |
| HKMA eTradeConnect | Finance | Hyperledger Fabric | Launched 31 October 2018 by 12 Hong Kong banks; built by OneConnect (Ping An) with Deloitte; MoU with we.trade to test connecting the two platforms | HKMA press release, 31 October 2018; GTR |
| MAS Project Ubin, Phase 2 | Finance | Corda, Fabric and Quorum prototypes | 13-week project with 11 financial institutions; report published 14 November 2017; showed RTGS functions and liquidity saving can be decentralized while keeping transactions private | Accenture, MAS and ABS release, 14 November 2017 |
| ASX CHESS replacement | Finance | DLT built by Digital Asset (contrast) | Digital Asset selected in 2017; cancelled 16 November 2022 after an Accenture review; A$245 to 255 million pre-tax write-off | The Block, 16 November 2022 |
| BIS Project Agora | Finance | Not stated (contrast) | Announced 3 April 2024 with 7 central banks; findings report 27 May 2026 with more than 40 financial institutions; real-value tests in July 2026 settled about CHF 800,000 across 17 scenarios, about 80 seconds on average | BIS and IIF report, 27 May 2026, as summarized by RegReportingDesk |
| Komgo | Finance | Quorum (contrast) | Founded 2018 in Geneva; still operating; more than 10,000 corporate users and connections with more than 60 banks; launched Global Trade Konnect in 2025 | Komgo newsroom, 7 November 2025 |
| Contour | Finance | R3 Corda (contrast) | Began as Voltron in 2017, live production October 2020; closed 30 November 2023 after bank shareholders declined to fund it | GTR; ICC DCW 2023 |
| Marco Polo | Finance | Corda (contrast) [VERIFY platform in a primary source] | Launched as TradeIX in 2016, rebranded 2021; provisional liquidators appointed in March 2023 | FinTech Futures, 7 March 2023 |
| TradeLens | Logistics | IBM Blockchain Platform on Hyperledger Fabric | Founded by Maersk and IBM in 2018; more than 300 organizations and data from more than 600 ports and terminals by July 2021; discontinuation announced 30 November 2022 because "full global industry collaboration has not been achieved"; offline by end of Q1 2023 | Port of Barcelona PierNext, 22 July 2021; Seatrade Maritime, 30 November 2022 |
| IBM Food Trust | Logistics | Hyperledger Fabric | General availability 8 October 2018; Walmart required leafy-greens suppliers to join by September 2019 (announced 24 September 2018); IBM described it in 2024 as a network of more than 900 partners | Supply Chain Dive; Grocery Dive; IBM Think, 2024; LF Decentralized Trust case study |
| Walmart mango trace | Logistics | IBM pilot | From 7 days to 2.2 seconds; testimony by Frank Yiannas, VP Food Safety, to the US House, 14 February 2018 | US House hearing record |
| Walmart Canada DL Freight | Logistics | Hyperledger Fabric (DLT Labs) | Rolled out early 2019; up to 70 carriers; invoice disputes fell from about 70% to about 1.5%; more than 200,000 invoices; one channel per carrier; more than 600 virtual machines | LF Decentralized Trust case study |
| DCSA eBL interoperability | Logistics | Several platforms, some blockchain-based | 4 June 2026: five eBL platforms adopted the DCSA Standard Annex v.2 with IG P&I approval, allowing bills of lading to move between platforms | DCSA press release, 4 June 2026 |
| Change Healthcare network | Healthcare | Hyperledger Fabric | Fabric network live since January 2018 in parallel with the existing network; up to 50 million transactions a day and up to 550 transactions a second | LF Decentralized Trust blog, 24 June 2019 |
| Avaneer Health | Healthcare | Hyperledger Fabric | Founded by Aetna, Anthem, Cigna, Cleveland Clinic, HCSC, IBM, PNC and Sentara; USD 50 million seed funding [VERIFY exact date, likely January 2022]; FHIR-based payer and provider data exchange | LF Decentralized Trust blog, 29 March 2022; Healthcare IT News |
| IBM Digital Health Pass | Healthcare | Hyperledger Fabric | Verifies health credentials such as the EU Digital COVID Certificate without storing personal data in the verifier app | LF Decentralized Trust blog, 29 March 2022 |
| MediLedger (DSCSA) | Healthcare | Not named in the sources found (contrast) | DSCSA pilot with 25 organizations reported to the FDA in 2020; used zero-knowledge proofs; concluded that standards and industry governance were still needed | Tablets & Capsules, 2 April 2020 |
| Honeywell GoDirect Trade | Industrial | Hyperledger Fabric | Used aircraft parts marketplace; more than 300 buyers and about USD 250,000 of sales in its first month, more than USD 1 million within 10 weeks; ledger records each part's lifecycle, repairs and owners | LF Decentralized Trust blog, 13 November 2019 |
| Circulor | Industrial | Hyperledger Fabric (with Oracle Cloud) | Volvo cobalt traceability pilot with Oracle in 2019; more than 150 million batteries and 500,000 EVs traced; underpins battery passports | LF Decentralized Trust case study; Cointelegraph, 11 November 2019; Oracle documentation |
| Botanical Water Exchange | Industrial | Hyperledger Fabric | Built by Fujitsu for Botanical Water Technologies; live Q2 2022; trades plant-sourced water and water impact credits; traces more than 170 touchpoints per harvesting unit | LF Decentralized Trust blog, 22 March 2023 |
| Everledger | Industrial | Not named in the sources found (contrast) | Founded 2015; administrators appointed 24 April 2023 after an investor withdrew | Rapaport; Web3 Is Going Just Great, 8 May 2023 |
| EU battery passport | Industrial | Regulation, not a platform | Article 77 of Regulation (EU) 2023/1542: EV, LMT and industrial batteries over 2 kWh need a passport from 18 February 2027 | Regulation (EU) 2023/1542 |

### 2.1 Cases dropped
- **ProCredEx.** Launched in 2018 for provider credentialing, but no source found names its platform. Dropped.
- **Tracr (De Beers).** Deployed at scale in 2022, but no source found names its platform. Dropped.

## 3 Technical, Standards and Regulatory Checks

**Table 2: Results of the technical and standards checks**

| Item | Finding | Source |
|---|---|---|
| Fabric 3.1.5 and Fabric CA | Fabric 3.1.5 is the latest 3.x release; Fabric CA 1.5.22 is the latest 1.5.x release | Git tags of both repositories |
| Solo, Kafka, system channel | All three removed in Fabric 3.0; the consortium concept went with the system channel | Fabric v3.0.0 release notes |
| Block dissemination by gossip | Deprecated in 3.0; peers receive blocks directly from the ordering service by default (blockGossipEnabled false) | Fabric v3.0.0 release notes |
| Raft membership changes | Consenters are added or removed one at a time, only while all consenters are healthy; the draft's "joint consensus" wording is wrong | Fabric 3.1.5 docs, raft_configuration |
| SmartBFT | Needs the V3_0 capability; BFT nodes identify each other by enrollment certificate, unlike Raft's TLS pinning; consenters listed in ConsenterMapping; protocol paper is arXiv 2107.06922 [VERIFY authors] | Fabric 3.1.5 docs, bft_configuration and ordering_service |
| Purge of private data | PurgePrivateData added in Fabric 2.5; requires the V2_5 application capability; removes data and its private history, leaving the hash | Fabric v2.5.0 whatsnew |
| PKCS#11 | Release binaries and images are built without PKCS#11 (nopkcs11); an HSM needs a build with GO_TAGS=pkcs11 | Fabric 3.1.5 docs, hsm; inspection of the 3.1.5 peer binary |
| Reads of a transaction's own writes | The shim documents that GetPrivateData does not read the transaction's uncommitted writes; the same behaviour for GetState is tested in Chapter 3 rather than assumed | fabric-shim 2.5.8 source |
| Go contract API | No NewLogger function and no mocks package in fabric-contract-api-go v2.2.4; the draft's test code cannot compile | fabric-contract-api-go repository |
| Application API | The 3.1.5 documentation lists only the Fabric Gateway client API for applications | Fabric 3.1.5 docs, sdk_chaincode |
| IBM Blockchain Platform | Support ended 30 April 2023; customers were told to move to IBM Support for Hyperledger Fabric | IBM Support |
| TypeScript | 5.9.3 builds the sample chaincode; 7.0.2 fails on its tsconfig (TS5011) | Phase 1 test |
| CouchDB | fabric-samples use couchdb:3.4.2 | fabric-samples, test-network-nano-bash |
| LF Decentralized Trust | Hyperledger Foundation became part of LF Decentralized Trust in September 2024; Sawtooth archived February 2024; Iroha 2.0 released; Cacti graduated October 2023 | Wikipedia (Hyperledger); LF Decentralized Trust blogs, 3 October 2023 and 16 September 2025 |
| Fabric-X | Announced by IBM Research on 1 May 2025 as a digital-asset variant of Fabric with ARMA BFT ordering; throughput figures are the authors' claims | LF Decentralized Trust blog, 1 May 2025 |
| ISO standards | ISO 22739:2024 is the current vocabulary standard, from ISO/TC 307 | StandICT; ANSI webstore |
| IEEE standards | Relevant published standards include 2418.2-2020 (data format), 3205-2023 (interoperability data authentication), 3209-2023 (identity key management), 3201-2024 (access control) and 3220.01-2025 (consensus framework) | IEEE Blockchain standards page |
| EDPB guidelines | Guidelines 02/2025 on processing personal data through blockchain technologies, final version adopted in July 2026 | EDPB news, 8 July 2026 |
| DORA | Regulation (EU) 2022/2554 applies from 17 January 2025 | EU Official Journal, via MFSA |
| FSMA 204 | The FDA food traceability rule compliance date is 20 July 2028 | FDA |

## 4 Cases Fixed for Each Chapter
Each chapter's Industry Applications section uses the four cases below. Chapter 6 is the case-study chapter and draws on the whole pool, so the limit of two appearances per case does not apply to it.

**Table 3: Industry Applications cases by chapter**

| Chapter | Finance | Logistics | Healthcare | Industrial |
|---|---|---|---|---|
| 1 | ASX CHESS replacement (contrast: when DLT was the wrong call) | TradeLens | Change Healthcare network | Honeywell GoDirect Trade |
| 2 | HKMA eTradeConnect | Walmart Canada DL Freight (a channel per carrier) | Avaneer Health | Circulor |
| 3 | we.trade | IBM Food Trust | IBM Digital Health Pass | Honeywell GoDirect Trade |
| 4 | MAS Project Ubin, Phase 2 | TradeLens (who runs the orderers) | Change Healthcare network (throughput) | Botanical Water Exchange |
| 5 | HKMA eTradeConnect (operating company) | Walmart Canada DL Freight (operations) | Avaneer Health (consortium operation) | Everledger (contrast: when the operator fails) |
| 6 | we.trade, Contour, Marco Polo, Komgo | TradeLens, IBM Food Trust, DL Freight | Change Healthcare, Avaneer, MediLedger | Honeywell, Circulor, Everledger |
| 7 | MAS Project Ubin (privacy findings) | IBM Food Trust (data ownership) | IBM Digital Health Pass (no personal data stored) | Circulor (battery passport data) |
| 8 | BIS Project Agora | DCSA eBL interoperability | MediLedger (interoperability and standards) | EU battery passport |

## 5 Effects on the Plan
- **Chapter 2.** The leader-peer section is rewritten: since Fabric 3.0, peers take blocks from the ordering service directly, and gossip carries private data and membership rather than blocks.
- **Chapter 4.** The membership-change passage follows the documented one-node-at-a-time rule, and the SmartBFT section explains identification by enrollment certificate.
- **Chapter 7.** Exercise 7.4 builds a PKCS#11-enabled peer from source with GO_TAGS=pkcs11; it stays optional.
- **Chapter 3.** A captured test settles whether a read sees the transaction's own uncommitted write, instead of the draft's claim.
- **Chapters 1 and 6.** The corrected dates for Komgo, Contour and Marco Polo, and the mango figure, replace the draft's.
- **Plan Table 9** is replaced by Table 1 of this register.

## 6 Still Open
These are resolved while the chapter concerned is drafted:
- SmartBFT paper authors (Chapter 4).
- Marco Polo's platform from a primary source (Chapter 6).
- Avaneer Health's seed funding date (Chapters 2 and 5).
- IBM Food Trust status after 2024 (Chapters 3 and 6).
- Change Healthcare network status after 2019 (Chapters 1 and 4).
- Minimum Docker Engine and Compose versions for readers (Chapter 5).

