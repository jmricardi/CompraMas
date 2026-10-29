import re

with open("app/src/main/java/com/example/network/Network.kt", "r") as f:
    content = f.read()

# Add new imports
imports = """import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Multipart
import retrofit2.http.Part
"""
content = content.replace("import retrofit2.http.Query", imports + "import retrofit2.http.Query")

# Add the new method to OpenFoodFactsService
new_method = """
    @Multipart
    @POST("cgi/product_image_upload.pl")
    suspend fun uploadProductImage(
        @Part("code") code: RequestBody,
        @Part("imagefield") imageField: RequestBody,
        @Part("user_id") userId: RequestBody,
        @Part("password") password: RequestBody,
        @Part image: MultipartBody.Part
    ): OffResponse
"""

content = content.replace('suspend fun getProduct(@Path("barcode") barcode: String): OffResponse', 'suspend fun getProduct(@Path("barcode") barcode: String): OffResponse\n' + new_method)

with open("app/src/main/java/com/example/network/Network.kt", "w") as f:
    f.write(content)
