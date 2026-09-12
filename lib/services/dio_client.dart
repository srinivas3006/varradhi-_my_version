// Re-export consolidated ApiClient and provide DioClient alias for backward compatibility.
import '../core/network/dio_client.dart';

export '../core/network/dio_client.dart';

typedef DioClient = ApiClient;
