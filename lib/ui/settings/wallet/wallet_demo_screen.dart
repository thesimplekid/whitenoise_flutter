import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whitenoise/config/extensions/toast_extension.dart';
import 'package:whitenoise/src/rust/api/wallet.dart';
import 'package:whitenoise/ui/core/themes/src/extensions.dart';
import 'package:whitenoise/ui/core/ui/custom_app_bar.dart';

class WalletDemoScreen extends ConsumerStatefulWidget {
  const WalletDemoScreen({super.key});

  @override
  ConsumerState<WalletDemoScreen> createState() => _WalletDemoScreenState();
}

class _WalletDemoScreenState extends ConsumerState<WalletDemoScreen> {
  final TextEditingController _mintUrlController = TextEditingController(
    text: 'https://fake.thesimplekid.dev', // Hardcoded mint URL
  );
  final TextEditingController _amountController = TextEditingController(
    text: '100', // Default amount in sats
  );
  
  CdkWallet? _wallet;
  String? _workDir;
  bool _isLoading = false;
  String? _balance;
  String? _lastQuote;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWorkDir();
  }

  @override
  void dispose() {
    _mintUrlController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initializeWorkDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _workDir = appDir.path;
      setState(() {});
    } catch (e) {
      _setError('Failed to get app directory: $e');
    }
  }

  Future<void> _createWallet() async {
    if (_workDir == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _wallet = await CdkWallet.newInstance();
      ref.showSuccessToast('Wallet created successfully!');
      setState(() {});
    } catch (e) {
      _setError('Failed to create wallet: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addMint() async {
    if (_wallet == null || _workDir == null) {
      _setError('Please create wallet first');
      return;
    }

    final mintUrl = _mintUrlController.text.trim();
    if (mintUrl.isEmpty) {
      _setError('Please enter a mint URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _wallet!.addMint(workDir: _workDir!, mintUrl: mintUrl);
      ref.showSuccessToast('Mint added successfully!');
    } catch (e) {
      _setError('Failed to add mint: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getBalance() async {
    if (_wallet == null || _workDir == null) {
      _setError('Please create wallet and add mint first');
      return;
    }

    final mintUrl = _mintUrlController.text.trim();
    if (mintUrl.isEmpty) {
      _setError('Please enter a mint URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final balance = await _wallet!.getBalance(workDir: _workDir!, mintUrl: mintUrl);
      setState(() {
        _balance = balance.toString();
      });
      ref.showSuccessToast('Balance retrieved: $balance sats');
    } catch (e) {
      _setError('Failed to get balance: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getMintQuote() async {
    if (_wallet == null || _workDir == null) {
      _setError('Please create wallet and add mint first');
      return;
    }

    final mintUrl = _mintUrlController.text.trim();
    final amountText = _amountController.text.trim();
    
    if (mintUrl.isEmpty) {
      _setError('Please enter a mint URL');
      return;
    }

    if (amountText.isEmpty) {
      _setError('Please enter an amount');
      return;
    }

    int amount;
    try {
      amount = int.parse(amountText);
    } catch (e) {
      _setError('Please enter a valid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final quote = await _wallet!.requestMintQuote(
        workDir: _workDir!,
        mintUrl: mintUrl,
        amountSats: BigInt.from(amount),
      );
      setState(() {
        _lastQuote = quote;
      });
      ref.showSuccessToast('Mint quote received!');
    } catch (e) {
      _setError('Failed to get mint quote: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setError(String error) {
    setState(() {
      _errorMessage = error;
    });
    ref.showErrorToast(error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.neutral,
      appBar: const CustomAppBar(title: Text('Wallet Demo')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Status
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Status',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: context.colors.primaryForeground,
                      ),
                    ),
                    Gap(8.h),
                    Text(
                      'Wallet: ${_wallet != null ? 'Created' : 'Not created'}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: context.colors.secondaryForeground,
                      ),
                    ),
                    Text(
                      'Work Directory: ${_workDir ?? 'Loading...'}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: context.colors.secondaryForeground,
                      ),
                    ),
                    if (_balance != null) ...[
                      Gap(4.h),
                      Text(
                        'Balance: $_balance sats',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: context.colors.primaryForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              Gap(24.h),
              
              // Create Wallet Button
              ElevatedButton(
                onPressed: _isLoading || _workDir == null ? null : _createWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.primaryForeground,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Create Wallet',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                ),
              ),
              
              Gap(16.h),
              
              // Mint URL Input
              Text(
                'Mint URL',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: context.colors.primaryForeground,
                ),
              ),
              Gap(8.h),
              TextField(
                controller: _mintUrlController,
                decoration: InputDecoration(
                  hintText: 'Enter mint URL (e.g., https://8333.space:3338)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                ),
                style: TextStyle(
                  color: context.colors.primaryForeground,
                  fontSize: 14.sp,
                ),
              ),
              
              Gap(16.h),
              
              // Add Mint Button
              ElevatedButton(
                onPressed: _isLoading || _wallet == null ? null : _addMint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.secondary,
                  foregroundColor: context.colors.secondaryForeground,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Add Mint',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                ),
              ),
              
              Gap(16.h),
              
              // Amount Input for Mint Quote
              Text(
                'Amount (sats)',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: context.colors.primaryForeground,
                ),
              ),
              Gap(8.h),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter amount in satoshis',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                ),
                style: TextStyle(
                  color: context.colors.primaryForeground,
                  fontSize: 14.sp,
                ),
              ),
              
              Gap(16.h),
              
              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _wallet == null ? null : _getBalance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.tertiary,
                        foregroundColor: context.colors.primaryForeground,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Get Balance',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  Gap(8.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _wallet == null ? null : _getMintQuote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: context.colors.primaryForeground,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Get Mint Quote',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
              
              Gap(24.h),
              
              // Results Section
              if (_lastQuote != null || _errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _errorMessage != null 
                        ? context.colors.destructive.withValues(alpha: 0.1)
                        : context.colors.baseMuted,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: _errorMessage != null 
                          ? context.colors.destructive
                          : context.colors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage != null ? 'Error' : 'Last Mint Quote',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: _errorMessage != null 
                              ? context.colors.destructive
                              : context.colors.primaryForeground,
                        ),
                      ),
                      Gap(8.h),
                      Text(
                        _errorMessage ?? _lastQuote!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: _errorMessage != null 
                              ? context.colors.destructive
                              : context.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Loading Indicator
              if (_isLoading) ...[
                Gap(24.h),
                Center(
                  child: CircularProgressIndicator(
                    color: context.colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
