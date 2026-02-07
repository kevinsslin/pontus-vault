# BoringVault 架構：Withdrawal 流程與 Vault Operation / Rebalance

本文說明在 BoringVault 架構下：(1) 提款流程與權限、(2) Vault 營運與 Rebalance 的運作方式。  
**注意**：BoringVault 是「可組合」架構，不同部署可能採用不同 Teller/Queue 組合；以下區分「庫裡有哪些機制」與「Pontus 實際怎麼用」。

---

## 一、Withdrawal 流程與權限

### 1.1 是否需要排隊？

**取決於部署時用的是哪一種「提款入口」。**

| 模式 | 是否需要排隊 | 說明 |
|------|----------------|------|
| **TellerWithMultiAssetSupport（僅 bulkWithdraw）** | 不一定 | 用戶**不能**直接呼叫 withdraw；只有具 Auth 的地址（如 Solver / TrancheController）能呼叫 `bulkWithdraw`。若沒有額外 Queue，就由該權限者「代用戶」提款，可做成即時或由後端排程。 |
| **Teller + AtomicQueue** | 是（依設計） | 用戶在 AtomicQueue 上提交「offer shares, want asset」的請求；Solver 稍後批次處理、呼叫 Teller 的 `bulkWithdraw` 並把 asset 轉給用戶。用戶提交一次 tx，幾天內由 Solver 完成，**對用戶而言是排隊**。 |
| **DelayedWithdraw / WithdrawQueue** | 是 | 用戶呼叫 `requestWithdraw(asset, shares, ...)` 登記提款請求；經過 `withdrawDelay` 後進入「可完成」區間（`maturity` ～ `maturity + completionWindow`）；用戶或第三方再呼叫 `completeWithdraw(asset, account)` 才真正燒 share、領 asset。 |

**Pontus 的情況**：  
TrancheController 持有 vault shares，並擁有 Teller 的 **Auth**（或等同權限），在用戶贖回 senior/junior 時**直接**呼叫 `teller.bulkWithdraw(...)`，**沒有**再套一層 Queue 或 DelayedWithdraw。所以對「從 Tranche 贖回」的用戶來說，是**即時**提款（一次 tx 完成），不是排隊。

---

### 1.2 誰可以決定是否允許 withdrawal 以及後續的 settle？

- **誰能執行「真正從 Vault 領出 asset」**  
  - BoringVault 的 `exit(to, asset, amount, from, shareAmount)` 只有具 **Auth** 的地址能呼叫（實作上多為 Teller 被設為該權限）。  
  - 在 **TellerWithMultiAssetSupport** 裡，只有 `bulkWithdraw` 會呼叫 `vault.exit(...)`，且 `bulkWithdraw` 是 `requiresAuth`，所以：  
    **誰有 Teller 的 Auth，誰就能決定「誰可以執行提款」**（通常是一個或多個 Solver / 後端 / 或像 Pontus 的 TrancheController）。

- **誰能「允許/拒絕」或「何時 settle」**  
  - **僅 Teller + bulkWithdraw**：沒有額外「審批」步驟；有 Auth 的人呼叫 bulkWithdraw 即執行。  
  - **AtomicQueue**：用戶提交請求後，由 **Solver**（有 Auth 的角色）決定何時 `solve`，即何時把請求兌現（呼叫 Teller.bulkWithdraw 等）。  
  - **DelayedWithdraw / WithdrawQueue**：  
    - 用戶自己或（若 `allowThirdPartyToComplete`）第三人可在 maturity 後、completion window 內呼叫 `completeWithdraw` 完成；  
    - Admin（MULTISIG / STRATEGIST_MULTISIG）可 `completeUserWithdraw`（甚至可不受 completion window 限制）、`cancelUserWithdraw`、以及調整 `withdrawDelay` / `completionWindow` / `withdrawFee` / `maxLoss`。  
  所以：**允許/拒絕與 settle 時機 = 擁有 Teller Auth 的人（或 Queue 的 Solver / DelayedWithdraw 的 Admin）。**

- **Manager 在 withdrawal 的角色**  
  **Manager 不參與 withdrawal。** Manager 只能呼叫 `vault.manage(target, data, value)` 做**策略操作**（例如 supply/withdraw 到外部協議）。  
  提款路徑是：**用戶/Queue → Teller（bulkWithdraw）→ vault.exit**，沒有經過 Manager。

---

### 1.3 Manager 在整體流程中扮演什麼角色？如何控管？

- **Manager 只負責「策略執行」**  
  - 唯一能力：以 BoringVault 的名義對外呼叫任意合約（`vault.manage(target, data, value)`）。  
  - 用於：把 vault 的資產投入/撤出策略（例如 OpenFi supply/withdraw、ERC4626 deposit/withdraw 等），即 **rebalance**。

- **控管方式**  
  - **ManagerWithMerkleVerification**：只執行「有 Merkle proof、且 leaf 在當前 root 允許集合內」的 call；leaf 編碼了 (decoderAndSanitizer, target, valueNonZero, selector, packedArgumentAddresses)。  
  - 因此：**誰能決定「哪些 call 被允許」= 誰能設定 Manager 的 `manageRoot`（通常為 Owner / Auth）**；**誰能發起 rebalance** = 誰能呼叫 `manageVaultWithMerkleVerification`（且帶正確 proof）— 通常為 Strategist 或同權限角色。

- **與 withdrawal 的關係**  
  Withdrawal 不經 Manager；Manager 不決定「用戶能不能提款」或「何時 settle」。  
  但若 vault 流動性不足（資產卡在策略裡），需要先透過 Manager 做 **rebalance**（例如從協議 withdraw）才能讓 Teller 的 bulkWithdraw 有足夠 asset 可領。

---

## 二、Vault Operation 與 Rebalance

### 2.1 什麼時候可以進行 rebalance？

- **鏈上沒有「冷靜期」或時間鎖**：只要  
  - Manager 沒被 pause，且  
  - 呼叫者具備 `manageVaultWithMerkleVerification` 的權限（Auth / Strategist 等），並能提供符合當前 `manageRoot` 的 Merkle proof，  
  就可以在**任意時間**發起 rebalance。

- **實際時機**通常由營運方（Operator / Strategist）或鏈下腳本決定，例如：  
  - 定期調倉、  
  - 目標配置偏離、  
  - 有大量提款需求需先從協議撤資等。

---

### 2.2 從 BoringVault 的角度，Vault Operation 如何運作？

- **BoringVault 本身**只做三件事：  
  1. **enter**（Minter 呼叫）：收 asset、鑄 share 給某人。  
  2. **exit**（Burner 呼叫）：燒某人的 share、把 asset 轉給指定對象。  
  3. **manage**（Manager 呼叫）：用 vault 的地址對外做任意 call（轉帳、呼叫協議等）。

- **Vault Operation 的實際分工**：  
  - **存入**：用戶 → Teller（deposit / bulkDeposit）→ Teller 呼叫 `vault.enter` → 用戶拿到 vault share（或經 TrancheController 拿到 senior/junior token）。  
  - **提款**：見上文；最終都是 Teller（或 DelayedWithdraw 內部）呼叫 `vault.exit`。  
  - **策略變動（rebalance）**：Operator/Strategist → Manager（`manageVaultWithMerkleVerification`）→ Manager 呼叫 `vault.manage(target, data, value)` 一筆或多筆，例如對 OpenFi Pool 做 supply/withdraw。

- 所以從 BoringVault 的視角：**Vault Operation = enter/exit（由 Teller 等權限者觸發）+ manage（由 Manager 觸發）**；沒有「rebalance」這個單一函式，rebalance 就是「一連串 manage call」。

---

### 2.3 從用戶端來看，rebalance 一般是怎麼進行的（資金進出）？

- **用戶不直接參與 rebalance**。  
  Rebalance 是「vault 的資產配置調整」：例如把 USDC 從 A 協議撤出、改存到 B 協議，或增加/減少在某個 Pool 的頭寸。

- **典型流程（概念）**：  
  1. 決策者（人或腳本）決定要執行哪些 call（例如 OpenFi withdraw 一筆、再 supply 到另一邊）。  
  2. 根據 Manager 的 Merkle 規則，為每筆 call 準備 (decoder, target, data, value) 與對應 **Merkle proof**。  
  3. 呼叫 `Manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values)`。  
  4. Manager 驗證 proof、對每筆呼叫 `vault.manage(target, data, value)`；vault 的資產（或負債）隨之變動。  
  5. 資金進出發生在「vault ↔ 外部協議」之間；**用戶的 vault share 數量不變**，但每 share 背後對應的資產組合改變了（所以 share 的價值/匯率可能變動，由 Accountant 的 exchange rate 反映）。

- **用戶看到的**：  
  存款/贖回時與 Teller（或 TrancheController）互動；若沒有特別 UI，用戶不會直接看到「rebalance」按鈕，rebalance 是後台/Operator 行為。

---

### 2.4 誰來決定 rebalance 的時機？背後有什麼參數或標準？

- **決定權**：  
  誰有權呼叫 `manageVaultWithMerkleVerification`（且能取得合法 proof），誰就**能**執行 rebalance；**時機**通常由該方（Operator / Strategist / 自動化腳本）決定，**鏈上沒有強制的參數或標準**。

- **常見鏈下參數/標準**（依產品設計）：  
  - 目標配置比例（例如 80% A protocol, 20% B）。  
  - 偏離閾值：偏離超過 X% 就觸發 rebalance。  
  - 提款預測：若預期大額贖回，可先從 illiquid 策略撤資。  
  - 風險/收益參數：例如某協議 APY 掉到某水準以下就減倉。  
  這些通常不在 BoringVault / Manager 合約裡，而是由後端或治理決定。

- **Pontus**：  
  目前 TrancheController 沒有 rebalance 邏輯；若要做 rebalance，需由具 Manager 權限的實體（例如 Operator 透過 Merkle proof）呼叫 Manager，且需具備 OpenFi 的 DecoderAndSanitizer 與 Merkle 建樹（如前文說明）。

---

## 三、Pontus 與 BoringVault 對照（簡表）

| 項目 | BoringVault 庫 | Pontus 實際 |
|------|----------------|-------------|
| 用戶存款 | Teller.deposit 或 bulkDeposit | 用戶 → TrancheController.depositSenior/Junior → Controller 呼叫 teller.deposit |
| 用戶提款 | 多為 Teller.bulkWithdraw（需 Auth）或 Queue/DelayedWithdraw | 用戶 → TrancheController.redeemSenior/Junior → Controller 呼叫 teller.bulkWithdraw；**即時、不排隊** |
| 誰能執行 bulkWithdraw | 擁有 Teller Auth 的地址 | TrancheController（被賦予 Teller Auth） |
| Rebalance | Manager.manageVaultWithMerkleVerification（需 proof） | 未實作（缺 OpenFi decoder + Merkle 建樹 + 呼叫流程） |
| Manager 與 withdrawal | 無關 | 無關 |

---

## 四、總結

1. **Withdrawal**  
   - 在「僅 Teller + bulkWithdraw」的部署（如 Pontus）：**不需要排隊**；有 Teller Auth 的合約（TrancheController）在用戶贖回時直接 bulkWithdraw。  
   - 若部署使用 AtomicQueue 或 DelayedWithdraw/WithdrawQueue，則**需要排隊**；允許/完成/取消由擁有對應 Auth 的角色（Solver / MULTISIG 等）決定。  
   - **Manager 不參與** withdrawal；只負責策略端的 `vault.manage`。

2. **Rebalance**  
   - **隨時**可執行（只要 Manager 未 pause、且有權限 + 合法 proof）。  
   - 從 BoringVault 角度 = 一連串 `vault.manage`；從用戶角度 = 後台營運，不直接操作。  
   - **時機與標準**由營運方/鏈下參數決定，鏈上無強制規則。

若你希望，我可以再補一段「Pontus 若要做第一次 rebalance，需要補齊的步驟清單」（Decoder、建樹、Operator 呼叫範例）。
