import '../../../utilities/amount/amount.dart';
import '../../crypto_currency/interfaces/electrumx_currency_interface.dart';
import 'pepecoin_wallet.dart';

/// Uses the upstream standard UTXO history, HD recovery and local signing flow.
class PublicElectrumWallet<T extends ElectrumXCurrencyInterface>
    extends PepecoinWallet<T> {
  PublicElectrumWallet(T currency) : super.forCurrency(currency);

  @override
  int get maximumFeerate => cryptoCurrency.defaultFeeRate.toInt() * 100;

  @override
  Amount roughFeeEstimate(
    int inputCount,
    int outputCount,
    BigInt feeRatePerKB,
  ) {
    // Conservative for both legacy and witness inputs; final fee uses vsize.
    return Amount(
      rawValue: BigInt.from(
        estimateTxFee(
          vSize: 10 + 148 * inputCount + 43 * outputCount,
          feeRatePerKB: feeRatePerKB,
        ),
      ),
      fractionDigits: cryptoCurrency.fractionDigits,
    );
  }

  @override
  int estimateTxFee({required int vSize, required BigInt feeRatePerKB}) {
    if (vSize < 0 || feeRatePerKB < BigInt.zero) {
      throw ArgumentError('Negative transaction size or fee rate');
    }
    return ((feeRatePerKB * BigInt.from(vSize) + BigInt.from(999)) ~/
            BigInt.from(1000))
        .toInt();
  }
}
