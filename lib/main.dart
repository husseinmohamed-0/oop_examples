import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

// ============================================================
// COLORS
// ============================================================

const Color primaryBlue = Color(0xFF2196F3);
const Color appBlack = Color(0xFF000000);
const Color appWhite = Color(0xFFFFFFFF);
const Color appGrey = Color(0xFF8A8A8A);
const Color appBackground = Color(0xFFF8F8F7);
const Color purple = Color(0xFF7B3FE4);

// ============================================================
// API
// ============================================================

class ApiConfig {
  static const String baseUrl = 'https://accessories-eshop.runasp.net/api';

  static const String products = '/products';
}

// ============================================================
// DIO
// ============================================================

class ApiClient {
  final Dio dio;

  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
}

// ============================================================
// USER ENTITY
// ============================================================

class User {
  final String email;

  const User({required this.email});
}

// ============================================================
// PRODUCT ENTITY
// ============================================================

class Product {
  final int id;
  final String name;
  final double price;
  final String image;
  final String description;
  final double rating;
  final String category;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.description,
    required this.rating,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _parseInt(json['id'] ?? json['productId'] ?? json['ProductId']),
      name: _parseString(
        json['name'] ?? json['productName'] ?? json['title'] ?? json['Name'],
        'Product',
      ),
      price: _parseDouble(
        json['price'] ?? json['Price'] ?? json['sellingPrice'],
      ),
      image: _getImage(json),
      description: _parseString(
        json['description'] ?? json['Description'] ?? json['details'],
        'No description available.',
      ),
      rating: _parseDouble(
        json['rating'] ?? json['Rating'] ?? json['rate'] ?? json['Rate'] ?? 5,
      ),
      category: _parseString(
        json['category'] ??
            json['categoryName'] ??
            json['Category'] ??
            'Accessories',
        'Accessories',
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static String _parseString(dynamic value, String fallback) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return fallback;
    }

    return result;
  }

  static String _getImage(Map<String, dynamic> json) {
    final image =
        json['image'] ??
        json['imageUrl'] ??
        json['imageURL'] ??
        json['productImage'] ??
        json['Image'] ??
        json['ImageUrl'];

    if (image != null) {
      return image.toString();
    }

    // Sometimes APIs return images as a list.
    final images = json['images'] ?? json['Images'] ?? json['productImages'];

    if (images is List && images.isNotEmpty) {
      final first = images.first;

      if (first is String) {
        return first;
      }

      if (first is Map) {
        return (first['url'] ?? first['imageUrl'] ?? first['image'])
                ?.toString() ??
            '';
      }
    }

    return '';
  }
}

// ============================================================
// AUTH - MOCK DATA SOURCE
// ============================================================

class MockAuthDataSource {
  User? currentUser;

  String? registeredEmail;
  String? registeredPassword;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    registeredEmail = email;
    registeredPassword = password;
  }

  Future<void> verify({required String email, required String otp}) async {
    await Future.delayed(const Duration(seconds: 1));

    if (otp.length != 6) {
      throw Exception('OTP must contain 6 digits.');
    }

    if (registeredEmail != email) {
      throw Exception('Email was not registered.');
    }
  }

  Future<User> login({required String email, required String password}) async {
    await Future.delayed(const Duration(seconds: 1));

    if (registeredEmail == null) {
      throw Exception('Please create an account first.');
    }

    if (email != registeredEmail || password != registeredPassword) {
      throw Exception('Invalid email or password.');
    }

    currentUser = User(email: email);

    return currentUser!;
  }
}

// ============================================================
// AUTH REPOSITORY
// ============================================================

class AuthRepository {
  final MockAuthDataSource dataSource;

  AuthRepository(this.dataSource);

  Future<void> register({required String email, required String password}) {
    return dataSource.register(email: email, password: password);
  }

  Future<void> verify({required String email, required String otp}) {
    return dataSource.verify(email: email, otp: otp);
  }

  Future<User> login({required String email, required String password}) {
    return dataSource.login(email: email, password: password);
  }
}

// ============================================================
// AUTH USE CASES
// ============================================================

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<void> call({required String email, required String password}) {
    return repository.register(email: email, password: password);
  }
}

class VerifyUseCase {
  final AuthRepository repository;

  VerifyUseCase(this.repository);

  Future<void> call({required String email, required String otp}) {
    return repository.verify(email: email, otp: otp);
  }
}

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<User> call({required String email, required String password}) {
    return repository.login(email: email, password: password);
  }
}

// ============================================================
// PRODUCT DATA SOURCE
// ============================================================

class ProductRemoteDataSource {
  final ApiClient client;

  ProductRemoteDataSource(this.client);

  Future<List<Product>> getProducts() async {
    final response = await client.dio.get(ApiConfig.products);

    final data = response.data;

    List<dynamic> list = [];

    if (data is List) {
      list = data;
    } else if (data is Map) {
      if (data['data'] is List) {
        list = data['data'];
      } else if (data['products'] is List) {
        list = data['products'];
      } else if (data['items'] is List) {
        list = data['items'];
      } else if (data['result'] is List) {
        list = data['result'];
      }
    }

    return list
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

// ============================================================
// PRODUCT REPOSITORY
// ============================================================

class ProductRepository {
  final ProductRemoteDataSource dataSource;

  ProductRepository(this.dataSource);

  Future<List<Product>> getProducts() {
    return dataSource.getProducts();
  }
}

// ============================================================
// PRODUCT USE CASE
// ============================================================

class GetProductsUseCase {
  final ProductRepository repository;

  GetProductsUseCase(this.repository);

  Future<List<Product>> call() {
    return repository.getProducts();
  }
}

// ============================================================
// DEPENDENCIES
// ============================================================

final apiClient = ApiClient();

final mockAuthDataSource = MockAuthDataSource();

final authRepository = AuthRepository(mockAuthDataSource);

final registerUseCase = RegisterUseCase(authRepository);

final verifyUseCase = VerifyUseCase(authRepository);

final loginUseCase = LoginUseCase(authRepository);

final productDataSource = ProductRemoteDataSource(apiClient);

final productRepository = ProductRepository(productDataSource);

final getProductsUseCase = GetProductsUseCase(productRepository);

// ============================================================
// APP
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SO Store',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: appBackground,
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();

    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Enter email and password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await loginUseCase(email: email, password: password);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductsPage()),
      );
    } catch (e) {
      showMessage(e.toString().replaceFirst('Exception: ', ''));
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          child: Column(
            children: [
              const SizedBox(height: 10),

              const Text(
                'Welcome to SO.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 35),

              socialButton(
                icon: const Text(
                  'G',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                text: 'Login with Google',
              ),

              const SizedBox(height: 12),

              socialButton(
                icon: const Icon(Icons.apple, color: Colors.black, size: 18),
                text: 'Login with Apple',
              ),

              const SizedBox(height: 12),

              socialButton(
                icon: const Icon(Icons.facebook, color: Colors.black, size: 18),
                text: 'Login with Facebook',
              ),

              const SizedBox(height: 24),

              const Text(
                'or by email',
                style: TextStyle(color: appGrey, fontSize: 13),
              ),

              const SizedBox(height: 18),

              input(controller: emailController, hint: 'Email'),

              const SizedBox(height: 13),

              input(
                controller: passwordController,
                hint: 'Password',
                obscure: hidePassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      hidePassword = !hidePassword;
                    });
                  },
                  icon: Icon(
                    hidePassword ? Icons.visibility_off : Icons.visibility,
                    color: appGrey,
                    size: 18,
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: appGrey, fontSize: 11),
                  ),
                ),
              ),

              const SizedBox(height: 5),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In  →',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: appGrey, fontSize: 12),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    child: const Text(
                      'Create an account',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget socialButton({required Widget icon, required String text}) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 9),
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget input({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: appGrey),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: purple, width: 2),
        ),
      ),
    );
  }
}

// ============================================================
// SIGN UP PAGE
// ============================================================

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final confirmController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    final email = emailController.text.trim();

    final password = passwordController.text;

    final confirm = confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      message('Please fill all fields.');
      return;
    }

    if (!email.contains('@')) {
      message('Please enter a valid email.');
      return;
    }

    if (password.length < 6) {
      message('Password must be at least 6 characters.');
      return;
    }

    if (password != confirm) {
      message('Passwords do not match.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await registerUseCase(email: email, password: password);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationPage(email: email, password: password),
        ),
      );
    } catch (e) {
      message(e.toString().replaceFirst('Exception: ', ''));
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            const Text(
              'Create account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Create your account to continue.',
              style: TextStyle(color: appGrey, fontSize: 14),
            ),

            const SizedBox(height: 35),

            authInput(controller: emailController, hint: 'Email'),

            const SizedBox(height: 15),

            authInput(
              controller: passwordController,
              hint: 'Password',
              obscure: true,
            ),

            const SizedBox(height: 15),

            authInput(
              controller: confirmController,
              hint: 'Confirm Password',
              obscure: true,
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget authInput({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: appGrey),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: purple, width: 2),
        ),
      ),
    );
  }
}

// ============================================================
// VERIFICATION PAGE
// ============================================================

class VerificationPage extends StatefulWidget {
  final String email;
  final String password;

  const VerificationPage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final otpController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      message('Enter a 6 digit OTP.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await verifyUseCase(email: widget.email, otp: otp);

      if (!mounted) return;

      message('Email verified successfully.');

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPageWithCredentials(
            email: widget.email,
            password: widget.password,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      message(e.toString().replaceFirst('Exception: ', ''));
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),

            const Text(
              'Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'We sent a verification code to\n${widget.email}',
              style: const TextStyle(color: appGrey, fontSize: 14),
            ),

            const SizedBox(height: 10),

            const Text(
              'Demo mode: enter any 6 digits.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),

            const SizedBox(height: 35),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(color: appGrey),
                counterText: '',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: purple, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN PAGE WITH CREDENTIALS
// ============================================================

class LoginPageWithCredentials extends StatefulWidget {
  final String email;
  final String password;

  const LoginPageWithCredentials({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<LoginPageWithCredentials> createState() =>
      _LoginPageWithCredentialsState();
}

class _LoginPageWithCredentialsState extends State<LoginPageWithCredentials> {
  late final TextEditingController emailController;

  late final TextEditingController passwordController;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    emailController = TextEditingController(text: widget.email);

    passwordController = TextEditingController(text: widget.password);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
    });

    try {
      await loginUseCase(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductsPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 50),

              const Text(
                'Email verified ✓',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Email',
                  hintStyle: TextStyle(color: appGrey),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(color: appGrey),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign In →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCTS PAGE
// ============================================================

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> products = [];

  bool loading = true;

  String selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Jewelry',
    'Bracelets',
    'Pendants',
    'Anklets',
  ];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final result = await getProductsUseCase();

      if (!mounted) return;

      setState(() {
        products = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load products: $e')));
    }
  }

  List<Product> get filteredProducts {
    if (selectedCategory == 'All') {
      return products;
    }

    return products.where((product) {
      return product.category.toLowerCase().contains(
        selectedCategory.toLowerCase(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadProducts,
          child: CustomScrollView(
            slivers: [
              // HEADER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.menu),
                      ),

                      const Spacer(),

                      const Text(
                        'YZ Accessories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.search),
                      ),

                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.shopping_bag_outlined),
                      ),
                    ],
                  ),
                ),
              ),

              // HERO
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Container(
                    height: 175,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'NEW COLLECTION',
                          style: TextStyle(
                            color: Color(0xFFFFD42A),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Discover our latest products',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 18),

                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                          ),
                          child: const Text(
                            'SHOP NOW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // CATEGORY TITLE
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 15, 20, 10),
                  child: Text(
                    'Categories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // CATEGORIES
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];

                      final selected = selectedCategory == category;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Colors.black
                                  : const Color(0xFFE2E2E2),
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // TITLE
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 25, 20, 12),
                  child: Text(
                    'Featured Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // LOADING
              if (loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              // EMPTY
              else if (filteredProducts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No products found.')),
                  ),
                )
              // PRODUCTS
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ProductCard(product: filteredProducts[index]);
                    }, childCount: filteredProducts.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 15,
                          childAspectRatio: .67,
                        ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD
// ============================================================

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: product.image.isNotEmpty
                          ? Image.network(
                              product.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return imagePlaceholder();
                              },
                            )
                          : imagePlaceholder(),
                    ),
                  ),

                  // DISCOUNT
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '15.0% OFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // CART
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFC107),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${product.price.toStringAsFixed(2)} EGP',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget imagePlaceholder() {
    return Container(
      color: const Color(0xFFE7E7E7),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey, size: 40),
      ),
    );
  }
}

// ============================================================
// PRODUCT DETAILS
// ============================================================

class ProductDetailsPage extends StatelessWidget {
  final Product product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Product Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Container(
              height: 380,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: product.image.isNotEmpty
                    ? Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return imagePlaceholder();
                        },
                      )
                    : imagePlaceholder(),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Spacer(),

                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFC107),
                        size: 18,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '${product.price.toStringAsFixed(2)} EGP',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    product.description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product added to cart'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text(
                        'ADD TO CART',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget imagePlaceholder() {
    return Container(
      color: const Color(0xFFE7E7E7),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey, size: 70),
      ),
    );
  }
}
