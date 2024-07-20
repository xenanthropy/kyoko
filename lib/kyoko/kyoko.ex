defmodule KyokoSupervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [Kyoko]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Kyoko do
  require Logger
  use Nostrum.Consumer

  alias Nostrum.Api
  import Meeseeks.XPath

  # Compile-time helper for defining Discord Application Command options
  opt = fn type, name, desc, opts ->
    %{type: type, name: name, description: desc}
    |> Map.merge(Enum.into(opts, %{}))
  end

  @kyoko_opts [
    opt.(
      3,
      "tags",
      "specify tags - separate tags with commas, e.g. 1girl,blonde_hair,pink_bowtie",
      required: false
    )
  ]

  @commands [
    {"kyoko", "generate a random image from safebooru", @kyoko_opts}
  ]

  def create_global_commands(app_id) do
    Enum.each(@commands, fn {name, description, options} ->
      Nostrum.Api.create_global_application_command(app_id, %{
        name: name,
        description: description,
        options: options
      })
    end)
  end

  def handle_event({:READY, %{application: %{id: app_id}} = _event, _ws_state}) do
    create_global_commands(app_id)
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    user_tags =
      if interaction.data.options do
        interaction.data.options
        |> Enum.find(fn option -> option.name == "tags" end)
        |> then(fn option -> option.value || "" end) || ""
      else
        # Default value for no tags option
        # Defaulting to 1girl because no tags takes too long for the API and fails often..
        "1girl"
      end

    case check_tags(user_tags) do
      {:restricted, restricted} ->
        Api.create_interaction_response(interaction, %{
          type: 4,
          data: %{content: restricted, flags: 64}
        })

      {:invalid, invalid} ->
        Api.create_interaction_response(interaction, %{
          type: 4,
          data: %{content: invalid, flags: 64}
        })

      {:valid, restricted_tags, bypass} ->
        case bypass do
          # making the bypass ephemeral in case a user generates something... questionable
          true -> Api.create_interaction_response(interaction, %{type: 5, data: %{flags: 64}})
          false -> Api.create_interaction_response(interaction, %{type: 5})
        end

        case generate_image(user_tags, restricted_tags, bypass) do
          {:msg, url, image_id} ->
            Api.edit_interaction_response(
              interaction.token,
              build_embed_response(url, image_id)
            )

          {:no_posts, error_message} ->
            # have to delete original interaction since we can't change a non-ephemeral interaction response to ephemeral
            # also have to edit interaction response first, otherwise `delete` will delete the followup message too...
            if bypass do
              Api.edit_interaction_response(interaction.token, %{content: error_message})
            else
              Api.edit_interaction_response(interaction.token, %{content: "error"})
              Api.create_followup_message(interaction.token, %{content: error_message, flags: 64})
              Api.delete_interaction_response(interaction)
            end

          _ ->
            # Handle unexpected return values from generate_image()
            IO.warn("Unexpected response from generate_image: #{inspect(interaction)}")

            Api.edit_interaction_response(interaction.token, %{
              content: "Unexpected error, sorry! :("
            })
        end
    end
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end

  def check_tags(user_tags) do
    restricted_tags = [
      "barefoot",
      "loli",
      "swimsuit",
      "bikini",
      "panties",
      "bra",
      "pantyshot",
      "underwear",
      "naked_apron",
      "nude",
      "shota"
    ]

    bypass = String.contains?(user_tags, "protocol_j")

    cond do
      String.contains?(user_tags, restricted_tags) && !bypass ->
        {:restricted, "your tags contain restricted tags! Please edit your tags and try again."}

      !Regex.match?(~r/^([a-z0-9,_]+)$/, user_tags) && !bypass && user_tags != "" ->
        {:invalid,
         "your tags contain invalid characters! Only alphanumerics (no caps), commas, and underscores are allowed."}

      true ->
        {:valid, restricted_tags, bypass}
    end
  end

  def generate_image(user_tags, restricted_tags, bypass) do
    full_tag_string = generate_tag_string(user_tags, restricted_tags, bypass)

    base_url = "https://safebooru.org/index.php?page=dapi&s=post&q=index&tags=#{full_tag_string}"

    Logger.debug("Full url: #{base_url}")
    parsed_xml = api_get_request(base_url)

    post_count = get_total_posts(parsed_xml)

    Logger.debug("post_count: #{post_count}")

    cond do
      post_count > 0 ->
        return_random_image(post_count, base_url)

      post_count == 0 ->
        {:no_posts,
         "Sorry, there are no images with those tags! Try different/less tags. (or api failure, yay safebooru...)"}
    end
  end

  def generate_tag_string(user_tags, restricted_tags, bypass) do
    restricted_tags_string = restricted_tags |> Enum.map_join("+-", fn i -> "#{i}" end)
    Logger.debug("Restricted_tags_string: #{restricted_tags_string}")

    full_restrict_string =
      case bypass do
        false -> "rating:safe+-#{restricted_tags_string}"
        true -> ""
      end

    Logger.debug("full_restrict_string: #{full_restrict_string}")

    fixed_tags =
      case bypass do
        true -> remove_bypass_tag(user_tags)
        false -> user_tags
      end

    Logger.debug("fixed_tags: #{fixed_tags}")

    tag_string =
      case fixed_tags do
        "" -> ""
        _ -> String.replace(fixed_tags, ",", "+")
      end

    Logger.debug("tag_string: #{tag_string}")

    full_tag_string =
      case full_restrict_string do
        "" -> "#{tag_string}"
        _ -> String.trim_trailing("#{full_restrict_string}+#{tag_string}", "+")
      end

    Logger.debug("full_tag_string: #{full_tag_string}")
    full_tag_string
  end

  def return_random_image(post_count, base_url) do
    post_modulo = rem(post_count, 100)
    Logger.debug("Post modulo: #{post_modulo}")
    # need to check for partially filled pages
    post_pages =
      case post_modulo do
        0 -> round(post_count / 100)
        ^post_count -> 1
        _ -> floor(post_count / 100 + 1)
      end

    Logger.debug("round(#{post_count} / 100) + 1) = #{post_pages}")
    Logger.debug("Post pages: #{post_pages}")
    # subtracting 1 because this will be an array index
    random_page =
      cond do
        post_pages == 1 -> 1
        post_pages > 1000 -> :rand.uniform(1000)
        true -> :rand.uniform(post_pages)
      end

    Logger.debug("Random page selected: #{random_page}")

    final_xml = api_get_request(base_url, random_page)

    post_count = get_total_posts(final_xml)

    if post_count != 0 do
      get_random_post(final_xml)
    else
      {:no_posts, "API failure! Please try again..."}
    end
  end

  def remove_bypass_tag(tags) do
    tags_1 = String.replace(tags, ",protocol_j", "")
    tags_2 = String.replace(tags_1, "protocol_j,", "")
    String.replace(tags_2, "protocol_j", "")
  end

  def build_embed_response(url, image_id) do
    %{
      embeds: [
        %{
          description:
            "ID: [#{image_id}](https://safebooru.org/index.php?page=post&s=view&id=#{image_id})",
          image: %{url: "#{url}"}
        }
      ]
    }
  end

  def build_error_response(error_message) do
    %{content: error_message, flags: 64}
  end

  def get_total_posts(request) do
    post_result =
      case request do
        {:error, _error} ->
          0

        _ ->
          Meeseeks.one(request, xpath("/posts"))
          |> Meeseeks.attrs()
      end

    cond do
      post_result == 0 || post_result == nil ->
        0

      true ->
        post_result
        |> Enum.at(0)
        |> Kernel.elem(1)
        |> Integer.parse()
        |> Kernel.elem(0)
    end
  end

  def api_get_request(base_url, random_page \\ 1, retry_count \\ 3) do
    request =
      HTTPoison.get!("#{base_url}&pid=#{random_page - 1}", [],
        timeout: 15000,
        recv_timeout: 15000
      ).body

    parsed_request = Meeseeks.parse(request, :xml)

    cond do
      get_total_posts(parsed_request) > 0 ->
        parsed_request

      retry_count == 0 ->
        {:error, "Max retries exceeded!"}

      true ->
        Logger.debug("Retrying GET request! #{retry_count} more tries!")
        Process.sleep(1500)
        api_get_request(base_url, random_page, retry_count - 1)
    end
  end

  def get_random_post(final_xml) do
    current_post_count = round(Meeseeks.all(final_xml, xpath("//post")) |> Enum.count())
    Logger.debug("Current post count: #{current_post_count}")

    random_post_number = :rand.uniform(current_post_count)
    Logger.debug("Random post selection: #{random_post_number}")

    selected_post_image =
      Meeseeks.one(final_xml, xpath("//post[#{random_post_number}]"))
      |> Meeseeks.attrs()
      |> Enum.at(2)
      |> Kernel.elem(1)

    image_id =
      Meeseeks.one(final_xml, xpath("//post[#{random_post_number}]"))
      |> Meeseeks.attrs()
      |> Enum.at(10)
      |> Kernel.elem(1)

    {:msg, selected_post_image, image_id}
  end
end
