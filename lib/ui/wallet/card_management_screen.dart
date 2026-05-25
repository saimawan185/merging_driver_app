import 'dart:developer';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../main.dart';
import '../../model/card_model.dart';
import '../../model/onePaySettingsModel.dart';
import '../../services/FirebaseHelper.dart';
import '../../services/helper.dart';
import '../wallet/paymenturlscreen.dart';
import 'genie_payment.dart';

class CardManagementScreen extends StatefulWidget {
  CardManagementScreen({
    super.key,
    required this.amount,
    required this.onPaymentSuccess,
    required this.onePaySettingData,
  });

  final String amount;
  final Function(bool) onPaymentSuccess;
  final OnePaySettingData? onePaySettingData;

  @override
  _CardManagementScreenState createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  List<CardModel> cards = [];
  bool isLoading = true;
  bool isProcessingPayment = false;
  bool isCreatingCustomer = false;
  String? errorMessage;
  String? customerId;

  OnePaySettingData? onePaySettingData;
  final GeniePayment geniePayment = GeniePayment();

  @override
  void initState() {
    super.initState();
    onePaySettingData = widget.onePaySettingData;
    initializeCustomerAndCards();
  }

  Future<void> initializeCustomerAndCards() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Step 1: Check if customer exists, create if not
      customerId = await _ensureCustomerExists();

      if (customerId == null) {
        setState(() {
          errorMessage = 'Failed to create payment account. Please try again.';
          isLoading = false;
        });
        return;
      }

      // Step 2: Load saved cards
      await loadCards();
    } catch (e) {
      log('Error initializing customer and cards: $e');
      setState(() {
        errorMessage = 'Failed to load payment information';
        isLoading = false;
      });
    }
  }

  Future<String?> _ensureCustomerExists() async {
    // If customer already exists, return it
    if (MyAppState.currentUser?.paymentCutomerId != null &&
        MyAppState.currentUser!.paymentCutomerId!.isNotEmpty) {
      return MyAppState.currentUser!.paymentCutomerId;
    }

    // Create new customer
    setState(() {
      isCreatingCustomer = true;
    });

    try {
      final newCustomerId = await geniePayment.createCustomerIfNeeded(
        user: MyAppState.currentUser!,
      );

      if (newCustomerId != null) {
        // Update user in Firestore and local state
        MyAppState.currentUser!.paymentCutomerId = newCustomerId;
        await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);

        log('Customer created successfully: $newCustomerId');
        return newCustomerId;
      } else {
        throw Exception('Failed to create customer');
      }
    } catch (e) {
      log('Error ensuring customer exists: $e');
      return null;
    } finally {
      setState(() {
        isCreatingCustomer = false;
      });
    }
  }

  Future<void> loadCards() async {
    if (customerId == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'No customer account found';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final savedCards = await geniePayment.getSavedCards(customerId!);
      setState(() {
        cards = savedCards;
      });
    } catch (e) {
      log('Error loading cards: $e');
      setState(() {
        errorMessage = 'Failed to load saved cards';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> addNewCard() async {
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please wait while we set up your payment account"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isProcessingPayment = true;
    });

    try {
      final Map<String, String>? cardData = await geniePayment.addCard(
        customerId: customerId!,
      );

      if (cardData != null && cardData['url'] != null) {
        // Redirect to card addition page
        final bool isDone = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentURLScreen(
              initialURl: cardData['url']!,
              transactionId: cardData['transaction_id']!,
              returnUrl:
                  onePaySettingData?.redirectUrl ?? GeniePayment.redirect_url,
            ),
          ),
        );

        if (isDone) {
          // Reload cards after successful addition
          await loadCards();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Card added successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to add card"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to initiate card addition"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      log('Error adding card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error adding card: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isProcessingPayment = false;
      });
    }
  }

  Future<void> deleteCard(CardModel card) async {
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot delete card: Customer account not found"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final bool? shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Card"),
          content: Text(
              "Are you sure you want to delete card ending in ${card.lastFourDigits}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      log("Token: ${card.token}");
      log("Token id: ${card.id}");

      final bool success = await geniePayment.deleteCard(customerId!, card.id);

      if (success) {
        // Remove card from local list
        setState(() {
          cards.removeWhere((c) => c.token == card.token);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Card deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete card"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      log('Error deleting card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting card: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> makePaymentWithCard(CardModel card) async {
    log("Token: ${card.token}");
    log("Token id: ${card.id}");

    if (isProcessingPayment) return;

    setState(() {
      isProcessingPayment = true;
    });

    try {
      log('Starting payment process with saved card: ${card.lastFourDigits}');

      // Step 1: Create payment transaction
      log('Step 1: Creating payment transaction...');
      final Map<String, String>? paymentData = await geniePayment.createPayment(
        context: context,
        user: MyAppState.currentUser!,
        amount: widget.amount,
        onePaySettingData: onePaySettingData,
        customerId: customerId,
      );

      if (paymentData == null) {
        throw Exception(
            'Failed to create payment transaction - no data returned');
      }

      if (paymentData['transaction_id'] == null) {
        throw Exception(
            'Failed to create payment transaction - no transaction ID');
      }

      final String transactionId = paymentData['transaction_id']!;
      log('Transaction created successfully: $transactionId');

      // Step 2: Charge the card using the transaction
      log('Step 2: Charging card with transaction: $transactionId');
      final Map<String, String>? chargeResult = await geniePayment.chargeCard(
        customerId!,
        transactionId,
        card.id,
      );

      if (chargeResult == null) {
        throw Exception('Card charge failed - no response from charge API');
      }

      log('Charge result: $chargeResult');

      // Handle the charge result
      await _handleChargeResult(chargeResult, transactionId);
    } catch (e) {
      log('Payment process error: $e');
      widget.onPaymentSuccess(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isProcessingPayment = false;
      });
    }
  }

  Future<void> _handleChargeResult(
      Map<String, String> chargeResult, String transactionId) async {
    if (chargeResult['vendorUrl'] != null &&
        chargeResult['vendorUrl']!.isNotEmpty) {
      log('3DS authentication required, redirecting to: ${chargeResult['vendorUrl']}');

      // Redirect to payment page for 3DS authentication
      final bool isDone = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentURLScreen(
            initialURl: chargeResult['vendorUrl']!,
            transactionId: transactionId,
            returnUrl:
                onePaySettingData?.redirectUrl ?? GeniePayment.redirect_url,
          ),
        ),
      );

      if (isDone) {
        log("payment successful!");
        Navigator.pop(context);
        widget.onPaymentSuccess(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment Successful!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        widget.onPaymentSuccess(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment was not completed"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Direct payment success (no 3DS required)
      log('Payment successful without 3DS redirect');
      Navigator.pop(context);

      widget.onPaymentSuccess(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment Successful!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> makeNewCardPayment() async {
    if (isProcessingPayment) return;

    setState(() {
      isProcessingPayment = true;
    });

    try {
      log('Creating new payment with new card');

      final Map<String, String>? paymentData = await geniePayment.createPayment(
        context: context,
        user: MyAppState.currentUser!,
        amount: widget.amount,
        onePaySettingData: onePaySettingData,
        customerId: customerId,
      );

      if (paymentData != null) {
        // Update customer ID if this is the first payment
        if (paymentData['customerId'] != null &&
            paymentData['customerId']!.isNotEmpty &&
            customerId == null) {
          customerId = paymentData['customerId']!;
          MyAppState.currentUser!.paymentCutomerId = customerId!;
          await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
        }

        // Redirect to payment page
        final bool isDone = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentURLScreen(
              initialURl: paymentData['url']!,
              transactionId: paymentData['transaction_id']!,
              returnUrl:
                  onePaySettingData?.redirectUrl ?? GeniePayment.redirect_url,
            ),
          ),
        );

        if (isDone) {
          // Reload cards in case a new card was added during payment
          await loadCards();
          widget.onPaymentSuccess(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Payment Successful!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          widget.onPaymentSuccess(false);
        }
      } else {
        widget.onPaymentSuccess(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment Failed!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      log('New payment error: $e');
      widget.onPaymentSuccess(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isProcessingPayment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: isDarkMode(context) ? Colors.white : Colors.black,
        ),
        title: Text(
          'My Cards',
          style: TextStyle(
            color: isDarkMode(context) ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Color(COLOR_PRIMARY),
        foregroundColor: isDarkMode(context) ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: initializeCustomerAndCards,
            color: isDarkMode(context) ? Colors.white : Colors.black,
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer creation loading
          if (isCreatingCustomer)
            LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Color(COLOR_PRIMARY)),
            ),

          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? _buildErrorState()
                    : cards.isEmpty
                        ? _buildEmptyState()
                        : _buildCardsList(),
          ),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            'Error loading cards',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 10),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: initializeCustomerAndCards,
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No saved cards',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add a card to make faster payments',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCardColor(card.brand),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.credit_card,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(
                  card.displayBrand,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (card.isDefault) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('**** ${card.lastFourDigits}'),
                Text('Expires ${card.expiryDate}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isProcessingPayment)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  ElevatedButton(
                    onPressed: () => makePaymentWithCard(card),
                    child: Text('Pay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(COLOR_PRIMARY),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onPressed: () => deleteCard(card),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // if (cards.isNotEmpty) ...[
          //   Container(
          //     width: double.infinity,
          //     child: isProcessingPayment
          //         ? Center(child: CircularProgressIndicator())
          //         : ElevatedButton.icon(
          //             onPressed: makeNewCardPayment,
          //             icon: Icon(Icons.payment),
          //             label: Text('Pay with New Card'),
          //             style: ElevatedButton.styleFrom(
          //               padding: EdgeInsets.symmetric(vertical: 16),
          //               backgroundColor: Colors.blue,
          //               foregroundColor: Colors.white,
          //             ),
          //           ),
          //   ),
          //   SizedBox(height: 8),
          // ],
          Container(
            width: double.infinity,
            child: isProcessingPayment
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: addNewCard,
                    icon: Icon(Icons.add_card),
                    label:
                        Text(cards.isEmpty ? 'Add Card' : 'Add Another Card'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Color(COLOR_PRIMARY),
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getCardColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'master':
      case 'mastercard':
        return Colors.orange;
      case 'visa':
        return Colors.blue;
      case 'amex':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
