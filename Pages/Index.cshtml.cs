// Pages/Index.cshtml.cs
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Newtonsoft.Json;

public class IndexModel : PageModel
{
    [BindProperty] public string? JsonInput { get; set; }
    public string? ResultTypeName { get; private set; }
    public string? ErrorMessage { get; private set; }

    public void OnGet()
    {
        // Preload a demonstration payload that shows how $type controls object instantiation
        JsonInput = @"{
  ""$type"": ""System.Diagnostics.ProcessStartInfo, System.Diagnostics.Process"",
  ""FileName"": ""echo"",
  ""Arguments"": ""Vulnerable: TypeNameHandling.Auto allows arbitrary types!""
}";
    }

    public void OnPost()
    {
        if (!string.IsNullOrEmpty(JsonInput))
        {
            try
            {
                // Insecure deserialization: TypeNameHandling.Auto allows $type in JSON to specify the object type
                var settings = new JsonSerializerSettings { TypeNameHandling = TypeNameHandling.Auto };
                object? obj = JsonConvert.DeserializeObject(JsonInput, settings);
                ResultTypeName = obj?.GetType().FullName ?? "(null)";
            }
            catch (Exception ex)
            {
                // Catch any errors (e.g., malformed JSON or exploitation attempt causing exception)
                ErrorMessage = ex.GetType().Name + ": " + ex.Message;
            }
        }
    }
}