use bip39::{Language, Mnemonic};
use cdk::mint_url::MintUrl;
use cdk::nuts::CurrencyUnit;
use cdk::wallet::types::WalletKey;
use cdk::wallet::{MultiMintWallet, Wallet};
use cdk::amount::SplitTarget;
use cdk::Amount;
use cdk_redb::wallet::WalletRedbDatabase;
use flutter_rust_bridge::frb;
use rand::Rng;
use std::fs;
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::{Arc, OnceLock};

/// Global wallet instance with lazy initialization
static GLOBAL_WALLET: OnceLock<Arc<MultiMintWallet>> = OnceLock::new();

/// Simple wallet wrapper
#[frb(opaque)]
pub struct CdkWallet {}

impl CdkWallet {
    /// Create a new wallet instance
    #[frb]
    pub fn new() -> Self {
        Self {}
    }

    #[frb]
    async fn get_wallet(&self, work_dir: &str, mint_url: &str) -> Result<Wallet, String> {
        let multi_mint_wallet = self.get_multi_mint_wallet(work_dir).await?;

        let mint_url = MintUrl::from_str(mint_url).map_err(|_| "invalid mint url".to_string())?;

        let wallet_key = WalletKey::new(mint_url.clone(), CurrencyUnit::Sat);

        let wallet = if let Some(wallet) = multi_mint_wallet.get_wallet(&wallet_key).await {
            wallet
        } else {
            multi_mint_wallet
                .create_and_add_wallet(&mint_url.to_string(), CurrencyUnit::Sat, None)
                .await
                .map_err(|_| "Could not add wallet".to_string())?;

            multi_mint_wallet
                .get_wallet(&wallet_key)
                .await
                .ok_or_else(|| "Could not get wallet".to_string())?
        };

        Ok(wallet)
    }

    /// Get the wallet instance, creating it if needed
    #[frb]
    async fn get_multi_mint_wallet(&self, work_dir: &str) -> Result<Arc<MultiMintWallet>, String> {
        // Try to get existing wallet first
        if let Some(wallet) = GLOBAL_WALLET.get() {
            return Ok(wallet.clone());
        }

        let work_dir = PathBuf::from_str(work_dir).map_err(|_| "bad work dir".to_string())?;

        let db_path = work_dir.join("cdk-wallet.redb");

        // Initialize wallet if not already done
        let database = Arc::new(
            WalletRedbDatabase::new(&db_path)
                .map_err(|e| format!("Failed to create database: {}", e))?,
        );

        let seed_path = work_dir.join("seed.txt");

        let seed = get_or_create_seed(seed_path)?;

        let wallet = Arc::new(MultiMintWallet::new(database, Arc::new(seed), vec![]));

        // Store the wallet in the global OnceLock - if another thread beat us to it,
        // that's fine, we'll just use their instance
        match GLOBAL_WALLET.set(wallet.clone()) {
            Ok(_) => Ok(wallet),
            Err(_) => {
                // Another thread initialized it first, use that instance
                Ok(GLOBAL_WALLET
                    .get()
                    .expect("Wallet was created by another thread")
                    .clone())
            }
        }
    }

    /// Request a mint quote from a mint
    #[frb]
    pub async fn request_mint_quote(
        &self,
        work_dir: &str,
        mint_url: &str,
        amount_sats: u64,
    ) -> Result<String, String> {
        let wallet = self.get_wallet(work_dir, mint_url).await?;

        let mint_quote = wallet
            .mint_quote(Amount::from(amount_sats), None)
            .await
            .map_err(|e| format!("Failed to get mint quote: {}", e))?;

        Ok(format!(
            "Quote ID: {} - Amount: {} sats - Payment Request: {}",
            mint_quote.id, mint_quote.amount, mint_quote.request
        ))
    }

    /// Check if a mint quote has been paid
    #[frb]
    pub async fn check_mint_quote_status(
        &self,
        work_dir: &str,
        mint_url: &str,
        quote_id: &str,
    ) -> Result<bool, String> {
        let wallet = self.get_wallet(work_dir, mint_url).await?;

        let quote_status = wallet
            .mint_quote_state(quote_id)
            .await
            .map_err(|e| format!("Failed to check quote status: {}", e))?;

        // For now, let's just check if the state exists and contains info indicating payment
        Ok(matches!(quote_status.state.to_string().as_str(), "Paid" | "paid"))
    }

    /// Mint tokens after a quote has been paid
    #[frb]
    pub async fn mint_tokens(
        &self,
        work_dir: &str,
        mint_url: &str,
        quote_id: &str,
    ) -> Result<String, String> {
        let wallet = self.get_wallet(work_dir, mint_url).await?;

        let receive_amount = wallet
            .mint(quote_id, SplitTarget::default(), None)
            .await
            .map_err(|e| format!("Failed to mint tokens: {}", e))?;

        Ok(format!("Successfully minted {} proofs", receive_amount.len()))
    }

    /// Add a mint to the wallet
    #[frb]
    pub async fn add_mint(&self, work_dir: &str, mint_url: &str) -> Result<(), String> {
        let multi_mint_wallet = self.get_multi_mint_wallet(work_dir).await?;

        let mint_url =
            MintUrl::from_str(mint_url).map_err(|e| format!("Invalid mint URL: {}", e))?;

        multi_mint_wallet
            .localstore
            .add_mint(mint_url, None)
            .await
            .map_err(|e| format!("Failed to add mint: {}", e))?;

        Ok(())
    }

    /// Get wallet balance for a specific mint
    #[frb]
    pub async fn get_balance(&self, work_dir: &str, mint_url: &str) -> Result<u64, String> {
        let wallet = self.get_wallet(work_dir, mint_url).await?;

        let balance = wallet
            .total_balance()
            .await
            .map_err(|e| format!("Failed to get balance: {}", e))?;

        Ok(balance.into()) // Convert Amount to u64
    }
}

/// Read seed from file or generate a new mnemonic and save it
///
/// This function will:
/// 1. Check if a seed file exists in the working directory
/// 2. If it exists, read and parse the mnemonic from it
/// 3. If it doesn't exist, generate a new mnemonic and save it to the file
///
/// # Parameters
/// * `seed_file_path` - Optional path to seed file (defaults to "seed.txt" in working directory)
///
/// # Returns
/// * `Result<[u8; 32], String>` - 32-byte seed or error message
fn get_or_create_seed(seed_path: PathBuf) -> Result<[u8; 32], String> {
    if seed_path.exists() {
        // Read existing mnemonic from file
        let mnemonic_string = fs::read_to_string(&seed_path)
            .map_err(|e| format!("Failed to read seed file {}: {}", seed_path.display(), e))?;

        let mnemonic_string = mnemonic_string.trim();
        let mnemonic = Mnemonic::parse_in(Language::English, mnemonic_string)
            .map_err(|e| format!("Failed to parse mnemonic from file: {}", e))?;

        // Convert mnemonic to seed
        let seed_bytes = mnemonic.to_seed_normalized("");

        if seed_bytes.len() < 32 {
            return Err("Generated seed is too short".to_string());
        }

        let mut result = [0u8; 32];
        result.copy_from_slice(&seed_bytes[0..32]);

        Ok(result)
    } else {
        // Generate new mnemonic
        let mut entropy = [0u8; 32];
        rand::thread_rng().fill(&mut entropy);

        let mnemonic = Mnemonic::from_entropy_in(Language::English, &entropy)
            .map_err(|e| format!("Failed to generate mnemonic: {}", e))?;

        // Save mnemonic to file
        fs::write(&seed_path, mnemonic.to_string())
            .map_err(|e| format!("Failed to write seed file {}: {}", seed_path.display(), e))?;

        // Convert mnemonic to seed
        let seed = mnemonic.to_seed_normalized("");

        if seed.len() < 32 {
            return Err("Generated seed is too short".to_string());
        }

        let mut result = [0u8; 32];
        result.copy_from_slice(&seed[0..32]);

        Ok(result)
    }
}
