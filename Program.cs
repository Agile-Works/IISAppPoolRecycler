using IISAppPoolRecycler.Services;

var builder = WebApplication.CreateBuilder(args);

// Configure for IIS integration
builder.Services.Configure<IISOptions>(options =>
{
    options.AutomaticAuthentication = false;
});

// Add services to the container.
builder.Services.AddScoped<IIISManagementService, IISManagementService>();

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    { 
        Title = "IIS App Pool Recycler API", 
        Version = "v1",
        Description = "API for automatically recycling IIS app pools based on Uptime Kuma webhooks"
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
