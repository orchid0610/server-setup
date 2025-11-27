#!/bin/bash
# Laravel Dev Server Setup with Multiple PHP Versions and Safe Checks

set -e

# --- Helper: check if package installed ---
is_installed() {
    dpkg -s "$1" &>/dev/null
}

echo "Enter your system username:"
read USERNAME

echo "Enter your project root folder name (e.g., www):"
read ROOT_FOLDER

ROOT_PATH="/home/$USERNAME/$ROOT_FOLDER"
mkdir -p "$ROOT_PATH"
echo "Created directory: $ROOT_PATH"

# --- Update system ---
echo "Updating package lists..."
sudo apt update -y

# --- Nginx ---
if is_installed nginx; then
    echo "✅ Nginx already installed. Skipping..."
else
    echo "Installing Nginx..."
    sudo apt install nginx -y
    sudo systemctl enable nginx
    sudo systemctl start nginx
fi

# Disable default site
if [ -f /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
    echo "Removed default nginx config."
fi

# --- Add PHP repository (for multiple versions) ---
if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Adding PHP repository..."
    sudo apt install -y software-properties-common
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update -y
else
    echo "✅ PHP repository already added. Skipping..."
fi

# --- Install multiple PHP versions and extensions ---
for version in 8.1 8.2 8.3; do
    if is_installed php$version-fpm; then
        echo "✅ PHP $version already installed. Skipping..."
    else
        echo "Installing PHP $version and extensions..."
        sudo apt install -y php$version php$version-fpm php$version-cli php$version-mysql \
            php$version-mbstring php$version-xml php$version-curl php$version-zip php$version-bcmath php$version-intl php$version-readline
        sudo systemctl enable php$version-fpm
        sudo systemctl start php$version-fpm
    fi
done

# --- Configure PHP CLI default ---
if update-alternatives --list php &>/dev/null; then
    echo "✅ PHP alternatives already configured."
else
    echo "Configuring PHP alternatives..."
    sudo update-alternatives --install /usr/bin/php php /usr/bin/php8.1 81
    sudo update-alternatives --install /usr/bin/php php /usr/bin/php8.2 82
    sudo update-alternatives --install /usr/bin/php php /usr/bin/php8.3 83
fi
sudo update-alternatives --set php /usr/bin/php8.3

# --- MySQL ---
if is_installed mysql-server; then
    echo "✅ MySQL already installed. Skipping..."
else
    echo "Installing MySQL..."
    sudo apt install mysql-server -y
    sudo systemctl enable mysql
    sudo systemctl start mysql
fi

# --- phpMyAdmin ---
if [ -d /usr/share/phpmyadmin ]; then
    echo "✅ phpMyAdmin already installed. Skipping..."
else
    echo "Installing phpMyAdmin non-interactively..."
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin
fi

# --- Add phpMyAdmin nginx config ---
if [ ! -f /etc/nginx/sites-available/phpmyadmin ]; then
    echo "Creating phpMyAdmin nginx config..."
    sudo tee /etc/nginx/sites-available/phpmyadmin >/dev/null <<EOL
server {
    listen 80;
    server_name phpmyadmin.test;
    root /usr/share/phpmyadmin;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
    sudo ln -sf /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/
    echo "127.0.0.1 phpmyadmin.test" | sudo tee -a /etc/hosts >/dev/null
else
    echo "✅ phpMyAdmin nginx config already exists. Skipping..."
fi

sudo systemctl restart nginx

# --- new-site script ---
if [ -f ./new-site ]; then
    if [ -f /usr/local/bin/new-site ]; then
        echo "✅ new-site already installed. Skipping copy..."
    else
        sudo cp ./new-site /usr/local/bin/new-site
        sudo chmod +x /usr/local/bin/new-site
        echo "Installed new-site command."
    fi
else
    echo "⚠️ new-site script not found in current directory!"
fi

# --- Done ---
echo ""
echo "🎉 Setup complete!"
echo "Your web root: $ROOT_PATH"
echo "phpMyAdmin: http://phpmyadmin.test"
echo ""
echo "To switch PHP CLI version later, use:"
echo "  sudo update-alternatives --config php"
echo ""
echo "To create a new site:"
echo "sudo new-site demo"
