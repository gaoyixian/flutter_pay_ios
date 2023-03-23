import 'dart:async';

import 'package:flutter_pay_interface/flutter_pay_interface.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// /// 支付类型
// const payTypeAlipay = 1;
// const payTypeWechat = 2;
const payTypeIos = 3;
// const payTypeBankcard = 4;

class FlutterPayIos implements FlutterPayInterface {
  static late InAppPurchase _inAppPurchase;
  static late StreamSubscription<List<PurchaseDetails>> _subscription;
  static late VerifyReceipt _verifyReceipt;
  static late void Function() _onError;
  @override
  Future<void> init(
      {required VerifyReceipt verifyReceipt,
      required LocalizationText localizationText,
      required void Function() onError}) async {
    _verifyReceipt = verifyReceipt;
    _onError = onError;
    _inAppPurchase = InAppPurchase.instance;
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription =
        purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (Object error) {
      // handle error here.
    });
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        //进行中
        print('~~~~~进行中');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _onError();
          print('~~~~~${purchaseDetails.error!}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _verifyReceipt(
              purchaseDetails.purchaseID,
              purchaseDetails.verificationData.serverVerificationData,
              _orderNumber);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  @override
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  String _orderNumber = '';
  @override
  Future<void> pay(dynamic rsp, int time) async {
    _orderNumber = getObjectKeyValueByPath(rsp, 'data.order_number');
    String productId = getObjectKeyValueByPath(rsp, 'data.ios_product_id');
    Set<String> set = {};
    set.add(productId);
    ProductDetailsResponse res = await _inAppPurchase.queryProductDetails(set);
    ProductDetails? productDetail;
    for (var item in res.productDetails) {
      if (item.id == productId) {
        productDetail = item;
      }
    }
    if (productDetail != null) {
      final purchaseParam = PurchaseParam(
          productDetails: productDetail, applicationUserName: "$time");
      _inAppPurchase.buyConsumable(
          purchaseParam: purchaseParam, autoConsume: true);
    }
  }

  @override
  Future<void> logout() async {
    _subscription.cancel();
  }
}
