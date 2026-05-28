import 'package:flutter/material.dart';

import 'arbitrage/arbitrage_calculator_page.dart';
import 'bankroll/bankroll_tracker_page.dart';
import 'cashback/cashback_cards_page.dart';
import 'credit_card/credit_card_payoff_page.dart';
import 'loan/loan_calculator_page.dart';
import 'parlay/parlay_calculator_page.dart';
import 'savings/savings_goals_page.dart';
import 'subscriptions/subscriptions_page.dart';
import 'tax/tax_bracket_reference_page.dart';
import 'tip/tip_split_calculator_page.dart';
import 'vig/vig_calculator_page.dart';
import 'worth_it/worth_it_analyzer_page.dart';

class FinanceSubmodule {
  const FinanceSubmodule({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.pageBuilder,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder pageBuilder;
}

class FinanceRegistry {
  static final List<FinanceSubmodule> all = [
    // Trackers (persisted)
    FinanceSubmodule(
      id: 'bills_subs',
      label: 'Bills & subscriptions',
      subtitle: 'Track recurring charges and renewals',
      icon: Icons.subscriptions_outlined,
      pageBuilder: (_) => const SubscriptionsPage(),
    ),
    FinanceSubmodule(
      id: 'savings',
      label: 'Savings & wishlist',
      subtitle: 'Track savings goals and wishlist items',
      icon: Icons.savings_outlined,
      pageBuilder: (_) => const SavingsGoalsPage(),
    ),
    FinanceSubmodule(
      id: 'cashback',
      label: 'Cashback cards',
      subtitle: 'Pick the best card for any purchase',
      icon: Icons.credit_card_outlined,
      pageBuilder: (_) => const CashbackCardsPage(),
    ),
    FinanceSubmodule(
      id: 'worth_it',
      label: 'Card worth-it analyzer',
      subtitle: 'Is your annual fee card paying for itself?',
      icon: Icons.balance,
      pageBuilder: (_) => const WorthItAnalyzerPage(),
    ),
    FinanceSubmodule(
      id: 'bankroll',
      label: 'Bankroll',
      subtitle: 'Log bets and track ROI',
      icon: Icons.casino_outlined,
      pageBuilder: (_) => const BankrollTrackerPage(),
    ),
    // Calculators (stateless)
    FinanceSubmodule(
      id: 'tip',
      label: 'Tip & split',
      subtitle: 'Tip + per-person split',
      icon: Icons.restaurant_outlined,
      pageBuilder: (_) => const TipSplitCalculatorPage(),
    ),
    FinanceSubmodule(
      id: 'loan',
      label: 'Loan calculator',
      subtitle: 'Monthly payments and total interest',
      icon: Icons.calculate_outlined,
      pageBuilder: (_) => const LoanCalculatorPage(),
    ),
    FinanceSubmodule(
      id: 'cc_payoff',
      label: 'Credit card payoff',
      subtitle: 'Time to payoff and interest paid',
      icon: Icons.credit_score_outlined,
      pageBuilder: (_) => const CreditCardPayoffPage(),
    ),
    FinanceSubmodule(
      id: 'taxes',
      label: 'Tax brackets',
      subtitle: '2025 federal income tax reference',
      icon: Icons.account_balance_outlined,
      pageBuilder: (_) => const TaxBracketReferencePage(),
    ),
    // Sports betting calculators
    FinanceSubmodule(
      id: 'arbitrage',
      label: 'Arbitrage calculator',
      subtitle: 'Guaranteed profit from sports bets',
      icon: Icons.compare_arrows,
      pageBuilder: (_) => const ArbitrageCalculatorPage(),
    ),
    FinanceSubmodule(
      id: 'vig',
      label: 'Vig (juice) calculator',
      subtitle: 'Bookmaker margin and no-vig odds',
      icon: Icons.trending_down,
      pageBuilder: (_) => const VigCalculatorPage(),
    ),
    FinanceSubmodule(
      id: 'parlay',
      label: 'Parlay calculator',
      subtitle: 'Multi-leg payout calculator',
      icon: Icons.layers_outlined,
      pageBuilder: (_) => const ParlayCalculatorPage(),
    ),
  ];
}
