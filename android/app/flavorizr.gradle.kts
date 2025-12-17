import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("staging") {
            dimension = "flavor-type"
            applicationId = "org.totem.app.staging"
            resValue(type = "string", name = "app_name", value = "Totem Development")
        }
        create("production") {
            dimension = "flavor-type"
            applicationId = "org.totem.app"
            resValue(type = "string", name = "app_name", value = "Totem")
        }
    }
}