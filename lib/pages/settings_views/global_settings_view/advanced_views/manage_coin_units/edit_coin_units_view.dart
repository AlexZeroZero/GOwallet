import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'choose_unit_sheet.dart';
import '../../../../../notifications/show_flush_bar.dart';
import '../../../../../providers/global/prefs_provider.dart';
import '../../../../../themes/stack_colors.dart';
import '../../../../../utilities/amount/amount_formatter.dart';
import '../../../../../utilities/amount/amount_unit.dart';
import '../../../../../utilities/assets.dart';
import '../../../../../utilities/constants.dart';
import '../../../../../utilities/text_styles.dart';
import '../../../../../utilities/util.dart';
import '../../../../../wallets/crypto_currency/crypto_currency.dart';
import '../../../../../widgets/background.dart';
import '../../../../../widgets/conditional_parent.dart';
import '../../../../../widgets/custom_buttons/app_bar_icon_button.dart';
import '../../../../../widgets/desktop/desktop_dialog.dart';
import '../../../../../widgets/desktop/desktop_dialog_close_button.dart';
import '../../../../../widgets/desktop/primary_button.dart';
import '../../../../../widgets/desktop/secondary_button.dart';
import '../../../../../widgets/icon_widgets/x_icon.dart';
import '../../../../../widgets/stack_text_field.dart';
import '../../../../../widgets/textfield_icon_button.dart';

class EditCoinUnitsView extends ConsumerStatefulWidget {
  const EditCoinUnitsView({super.key, required this.coin});

  final CryptoCurrency coin;

  static const String routeName = "/editCoinUnitsView";

  @override
  ConsumerState<EditCoinUnitsView> createState() => _EditCoinUnitsViewState();
}

class _EditCoinUnitsViewState extends ConsumerState<EditCoinUnitsView> {
  late final TextEditingController _decimalsController;
  late final FocusNode _decimalsFocusNode;

  late AmountUnit _currentUnit;

  /// The most decimals this coin can meaningfully show.
  ///
  /// The coin's own precision, since asking for more than the chain has does
  /// not reveal another digit — it just pads zeros, and
  /// [AmountUnit.displayAmount] caps at this internally anyway, so anything
  /// above it was a setting that did nothing while looking like it worked.
  ///
  /// Then 18, which is not a number picked here. Prefs._setMaxDecimals caps
  /// the DEFAULT the same way, commented "use some sane max rather than up to
  /// 30 that nano uses" — Nano really does declare 30 fraction digits and
  /// Banano 29. Upstream bounded what it chose for you and left what you type
  /// unbounded; this is the same ceiling applied to both, so the field cannot
  /// be set to something the app would never have defaulted to.
  ///
  /// Identical to fractionDigits for every coin we currently ship, all of
  /// which are 8. It matters the day Nano or Banano is switched on.
  static const _saneMaxDecimals = 18;
  int get _maxAllowed => widget.coin.fractionDigits > _saneMaxDecimals
      ? _saneMaxDecimals
      : widget.coin.fractionDigits;

  void onSave() {
    final entered = int.tryParse(_decimalsController.text.trim());

    // Refuse rather than silently discard. This used to return on a null and
    // leave the screen open with a Save that appeared to do nothing.
    if (entered == null) {
      showFloatingFlushBar(
        type: FlushBarType.warning,
        message: goTr(context, "Enter a number between 0 and {0}.", [
          _maxAllowed,
        ]),
        context: context,
      );
      return;
    }

    // Clamped, not rejected: the intent of "12" on an 8 decimal coin is
    // plainly "as many as possible", and of a negative "none".
    //
    // The lower bound is the one that matters. A negative reaches a substring
    // inside displayAmount and throws on every amount the app draws — the
    // assert that was supposed to catch it is compiled out of release builds.
    final maxDecimals = entered.clamp(0, _maxAllowed);
    if (maxDecimals != entered) {
      _decimalsController.text = maxDecimals.toString();
    }

    ref
        .read(prefsChangeNotifierProvider)
        .updateAmountUnit(coin: widget.coin, amountUnit: _currentUnit);
    ref
        .read(prefsChangeNotifierProvider)
        .updateMaxDecimals(coin: widget.coin, maxDecimals: maxDecimals);

    Navigator.of(context).pop();
  }

  Future<void> chooseUnit() async {
    final chosenUnit = await showModalBottomSheet<AmountUnit?>(
      backgroundColor: Colors.transparent,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ChooseUnitSheet(coin: widget.coin);
      },
    );

    if (chosenUnit != null) {
      setState(() {
        _currentUnit = chosenUnit;
      });
    }
  }

  @override
  void initState() {
    _decimalsFocusNode = FocusNode();
    _decimalsController = TextEditingController()
      ..text = ref.read(pMaxDecimals(widget.coin)).toString();
    _currentUnit = ref.read(pAmountUnit(widget.coin));
    super.initState();
  }

  @override
  void dispose() {
    _decimalsFocusNode.dispose();
    _decimalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalParent(
      condition: Util.isDesktop,
      builder: (child) => DesktopDialog(
        maxHeight: 350,
        maxWidth: 500,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    goTr(context, "Edit {0} units", [widget.coin.prettyName]),
                    style: STextStyles.desktopH3(context),
                  ),
                ),
                const DesktopDialogCloseButton(),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                child: child,
              ),
            ),
          ],
        ),
      ),
      child: ConditionalParent(
        condition: !Util.isDesktop,
        builder: (child) => Background(
          child: Scaffold(
            backgroundColor: Theme.of(
              context,
            ).extension<StackColors>()!.background,
            appBar: AppBar(
              leading: AppBarBackButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              title: Text(
                goTr(context, "Edit {0} units", [widget.coin.prettyName]),
                style: STextStyles.navBarTitle(context),
              ),
            ),
            body: SafeArea(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
        child: Column(
          children: [
            if (Util.isDesktop)
              DropdownButtonHideUnderline(
                child: DropdownButton2<AmountUnit>(
                  value: _currentUnit,
                  items: [
                    ...AmountUnit.valuesForCoin(widget.coin).map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e.unitForCoin(widget.coin),
                          style: STextStyles.desktopTextMedium(context),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value is AmountUnit) {
                      _currentUnit = value;
                    }
                  },
                  isExpanded: true,
                  iconStyleData: IconStyleData(
                    icon: SvgPicture.asset(
                      Assets.svg.chevronDown,
                      width: 12,
                      height: 6,
                      color: Theme.of(context)
                          .extension<StackColors>()!
                          .textFieldActiveSearchIconRight,
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    offset: const Offset(0, -10),
                    elevation: 0,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).extension<StackColors>()!.textFieldDefaultBG,
                      borderRadius: BorderRadius.circular(
                        Constants.size.circularBorderRadius,
                      ),
                    ),
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            if (!Util.isDesktop)
              Stack(
                children: [
                  TextField(
                    autocorrect: Util.isDesktop ? false : true,
                    enableSuggestions: Util.isDesktop ? false : true,
                    // controller: _lengthController,
                    readOnly: true,
                    textInputAction: TextInputAction.none,
                  ),
                  Positioned.fill(
                    child: RawMaterialButton(
                      splashColor: Theme.of(
                        context,
                      ).extension<StackColors>()!.highlight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Constants.size.circularBorderRadius,
                        ),
                      ),
                      onPressed: chooseUnit,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 17),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _currentUnit.unitForCoin(widget.coin),
                              style: STextStyles.itemSubtitle12(context),
                            ),
                            SvgPicture.asset(
                              Assets.svg.chevronDown,
                              width: 14,
                              height: 6,
                              color: Theme.of(context)
                                  .extension<StackColors>()!
                                  .textFieldActiveSearchIconRight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: Util.isDesktop ? 24 : 16),
            // A real label on its own line, not the field's floating one.
            //
            // An OutlineInputBorder floats its label ONTO the top border, so
            // half the text sits above the field's own box by design. That
            // needs room above the field and a background to sit against, and
            // this screen gives it neither: wrapped in a ClipRRect it was cut
            // in half, and unwrapped it escaped into the 8px gap and collided
            // with the unit selector above.
            //
            // Two controls stacked this tightly have nowhere to float a label
            // into, so the label stops floating. It also stops depending on
            // the field's state — the old one only appeared once the field had
            // content, which is backwards for the one word that says what the
            // number means.
            // Aligned explicitly: this Column centres its children by default,
            // and the two fields only look left-aligned because they stretch
            // the full width. A bare Text does not, so it centred itself over
            // the field it labels.
            Align(
              alignment: AlignmentDirectional.centerStart,
              // The range is in the label because it is a hard limit, not a
              // suggestion, and a field that silently corrects what you typed
              // is worse than one that told you the rule first.
              child: Text(
                goTr(context, "Maximum precision (0 to {0})", [_maxAllowed]),
                style: STextStyles.fieldLabel(context),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              autocorrect: Util.isDesktop ? false : true,
              enableSuggestions: Util.isDesktop ? false : true,
              key: const Key("addCustomNodeNodeNameFieldKey"),
              controller: _decimalsController,
              focusNode: _decimalsFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              style: STextStyles.field(context),
              decoration:
                  standardInputDecoration(
                    null,
                    _decimalsFocusNode,
                    context,
                  ).copyWith(
                    suffixIcon: _decimalsController.text.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 0),
                            child: UnconstrainedBox(
                              child: Row(
                                children: [
                                  TextFieldIconButton(
                                    child: const XIcon(),
                                    onTap: () async {
                                      _decimalsController.text = "";
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
            ),
            const SizedBox(height: 24),
            const Spacer(),
            ConditionalParent(
              condition: Util.isDesktop,
              builder: (child) => Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: goTr(context, "Cancel"),
                      buttonHeight: ButtonHeight.l,
                      onPressed: Navigator.of(context).pop,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: child),
                ],
              ),
              child: PrimaryButton(
                label: goTr(context, "Save"),
                buttonHeight: Util.isDesktop ? ButtonHeight.l : ButtonHeight.xl,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
