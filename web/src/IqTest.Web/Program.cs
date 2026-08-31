using IqTest.Application;
using IqTest.Infrastructure;
using IqTest.Infrastructure.Persistence;
using IqTest.Web.Api;
using IqTest.Web.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment.ContentRootPath);

builder.Services.AddRazorPages();
builder.Services.AddProblemDetails();
builder.Services.AddHttpContextAccessor();

// The mobile app posts from another origin.
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy
    .AllowAnyOrigin()
    .AllowAnyHeader()
    .WithMethods("GET", "POST")));

var app = builder.Build();

if (app.Configuration.GetValue($"{DatabaseOptions.SectionName}:{nameof(DatabaseOptions.MigrateOnStartup)}", true))
{
    // No EF, so the schema is applied by replaying idempotent scripts.
    await using var scope = app.Services.CreateAsyncScope();
    await scope.ServiceProvider.GetRequiredService<DatabaseMigrator>().MigrateAsync();
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStatusCodePagesWithReExecute("/Error/{0}");
app.UseStaticFiles();
app.UseRouting();
app.UseCors();

app.UseMiddleware<DomainExceptionMiddleware>();

app.MapRazorPages();
app.MapApiEndpoints();

app.Run();

/// <summary>Exposed so the integration tests can host the app in memory.</summary>
public partial class Program;
